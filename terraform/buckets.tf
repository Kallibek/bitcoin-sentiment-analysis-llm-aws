############################
# S3 Buckets
############################

resource "aws_s3_bucket" "raw_tweets_bucket" {
  bucket = var.raw_tweets_bucket_name
}

resource "aws_s3_bucket" "tweet_sentiments_bucket" {
  bucket = var.tweet_sentiments_bucket_name
}


resource "aws_s3_bucket" "aggregated_bucket" {
  bucket = var.aggregated_bucket_name
}


# Bucket for Glue job scripts (if desired)
resource "aws_s3_bucket" "glue_scripts_bucket" {
  bucket = var.glue_scripts_bucket_name
}