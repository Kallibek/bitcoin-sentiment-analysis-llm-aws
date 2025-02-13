variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "raw_tweets_bucket_name" {
  description = "S3 bucket name for raw tweet data."
  type        = string
  default     = "my-raw-tweets-bucket-unique"
}

variable "aggregated_bucket_name" {
  description = "S3 bucket name for aggregated results."
  type        = string
  default     = "my-aggregated-results-bucket-unique"
}

variable "glue_scripts_bucket_name" {
  description = "S3 bucket for storing Glue job scripts."
  type        = string
  default     = "my-glue-scripts-bucket-unique"
}

variable "tweet_sentiments_bucket_name" {
  description = "S3 bucket for storing tweet sentiments"
  type        = string
  default     = "my-tweet-sentiments-bucket-unique"
}

variable "aggregation_window" {
  description = "Window in seconds for aggregation (e.g. 3600 for hourly)."
  type        = number
  default     = 60
}

variable "openai_api_key" {
  description = "OpenAI API Key (secret) for GPT sentiment analysis."
  type        = string
  sensitive   = true
}
