provider "aws" {
  region = var.aws_region
}

############################
# AWS Secrets Manager – OpenAI API Key
############################

resource "aws_secretsmanager_secret" "openai_api" {
  name = "openai_api_key"
}

resource "aws_secretsmanager_secret_version" "openai_api_version" {
  secret_id     = aws_secretsmanager_secret.openai_api.id
  secret_string = var.openai_api_key
}

############################
# Kinesis Streams
############################

resource "aws_kinesis_stream" "tweets_stream" {
  name             = "tweets_stream"
  shard_count      = 1
  retention_period = 24
}

resource "aws_kinesis_stream" "sentiments_stream" {
  name             = "sentiments_stream"
  shard_count      = 1
  retention_period = 24
}

############################
# Kinesis Firehose to archive raw tweets
############################

resource "aws_iam_role" "firehose_role" {
  name = "firehose_delivery_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "firehose_delivery_policy"
  description = "Policy for Firehose to write to S3 and describe the Kinesis stream"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:AbortMultipartUpload",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = [
          aws_s3_bucket.raw_tweets_bucket.arn,
          "${aws_s3_bucket.raw_tweets_bucket.arn}/*",
          aws_s3_bucket.tweet_sentiments_bucket.arn,
          "${aws_s3_bucket.tweet_sentiments_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards"
        ],
        Resource = [
          aws_kinesis_stream.tweets_stream.arn,
          aws_kinesis_stream.sentiments_stream.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_policy_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_kinesis_firehose_delivery_stream" "tweets_to_s3" {
  name        = "tweets_to_s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.tweets_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.raw_tweets_bucket.arn
    buffering_interval  = 60
    buffering_size      = 1
    compression_format  = "UNCOMPRESSED"
    prefix              = "data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  }

}

resource "aws_kinesis_firehose_delivery_stream" "tweet_sentiments_to_s3" {
  name        = "tweet_sentiments_to_s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.sentiments_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.tweet_sentiments_bucket.arn
    buffering_interval  = 60
    buffering_size      = 1
    compression_format  = "UNCOMPRESSED"
    prefix              = "data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

  }

}