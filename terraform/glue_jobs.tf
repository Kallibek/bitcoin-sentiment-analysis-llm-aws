############################
# IAM Role for Glue Jobs
############################

resource "aws_iam_role" "glue_role" {
  name = "glue_service_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach basic policies for Glue and access to S3, Kinesis, and Secrets Manager.
resource "aws_iam_role_policy" "glue_policy" {
  name = "glue_policy"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.raw_tweets_bucket.arn,
          "${aws_s3_bucket.raw_tweets_bucket.arn}/*",
          aws_s3_bucket.aggregated_bucket.arn,
          "${aws_s3_bucket.aggregated_bucket.arn}/*",
          aws_s3_bucket.glue_scripts_bucket.arn,
          "${aws_s3_bucket.glue_scripts_bucket.arn}/*",
          aws_s3_bucket.tweet_sentiments_bucket.arn,
          "${aws_s3_bucket.tweet_sentiments_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:*"
        ]
        Resource = [
          aws_kinesis_stream.tweets_stream.arn,
          aws_kinesis_stream.sentiments_stream.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

############################
# Upload Glue Job Scripts to S3
############################

# Assume you have local files in the glue_scripts/ folder.

resource "aws_s3_object" "tweet_generator_script" {
  bucket = aws_s3_bucket.glue_scripts_bucket.id
  key    = "tweet_generator.py"
  source = "../glue_scripts/tweet_generator.py"
  etag   = filemd5("../glue_scripts/tweet_generator.py")
}

resource "aws_s3_object" "sentiment_analysis_script" {
  bucket = aws_s3_bucket.glue_scripts_bucket.id
  key    = "sentiment_analysis.py"
  source = "../glue_scripts/sentiment_analysis.py"
  etag   = filemd5("../glue_scripts/sentiment_analysis.py")
}

resource "aws_s3_object" "streaming_aggregation_script" {
  bucket = aws_s3_bucket.glue_scripts_bucket.id
  key    = "streaming_aggregation.py"
  source = "../glue_scripts/streaming_aggregation.py"
  etag   = filemd5("../glue_scripts/streaming_aggregation.py")
}

############################
# Glue Job: Tweet Generator
############################

resource "aws_glue_job" "tweet_generator" {
  name     = "tweet_generator_job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    python_version  = "3.9"
    script_location = "s3://${aws_s3_bucket.glue_scripts_bucket.bucket}/tweet_generator.py"
    name            = "pythonshell"

  }

  default_arguments = {
    "--additional-python-modules" = "openai"
    "--openai_secret_id"          = aws_secretsmanager_secret.openai_api.id
    "--tweets_stream"             = aws_kinesis_stream.tweets_stream.name
  }

  max_capacity = "0.0625"
}

############################
# Glue Job: Sentiment Analysis
############################

resource "aws_glue_job" "sentiment_analysis" {
  name     = "sentiment_analysis_job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    python_version  = "3.9"
    name            = "pythonshell"
    script_location = "s3://${aws_s3_bucket.glue_scripts_bucket.bucket}/sentiment_analysis.py"
  }
  max_capacity = "0.0625"

  default_arguments = {
    "--additional-python-modules" = "openai"
    "--openai_secret_id"          = aws_secretsmanager_secret.openai_api.id
    "--tweets_stream"             = aws_kinesis_stream.tweets_stream.name
    "--sentiments_stream"         = aws_kinesis_stream.sentiments_stream.name
  }
}

############################
# Glue Job: Streaming Aggregation (PySpark)
############################

resource "aws_glue_job" "streaming_aggregation" {
  name     = "streaming_aggregation_job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    python_version  = "3"
    name            = "gluestreaming"
    script_location = "s3://${aws_s3_bucket.glue_scripts_bucket.bucket}/streaming_aggregation.py"
  }

  number_of_workers = 2
  worker_type       = "G.1X"


  default_arguments = {
    "--aggregation_window" = var.aggregation_window
    "--output_bucket"      = aws_s3_bucket.aggregated_bucket.bucket
    "--sentiments_stream"  = aws_kinesis_stream.sentiments_stream.name
  }
}