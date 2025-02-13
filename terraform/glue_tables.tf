############################
# Glue Catalog Database and Tables
############################

# Glue Catalog Database
resource "aws_glue_catalog_database" "tweets_database" {
  name = "tweets_database"
}

############################
# Glue Table: Raw Tweets
############################
# This table reflects the output of tweet_generator.py, which writes records with:
# { "id": <uuid>, "timestamp": <ISO timestamp>, "text": <tweet text> }

resource "aws_glue_catalog_table" "raw_tweets" {
  name          = "raw_tweets"
  database_name = aws_glue_catalog_database.tweets_database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification  = "json"
    compressionType = "none"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.raw_tweets_bucket.bucket}/data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "raw_tweets_serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "id"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "text"
      type = "string"
    }
  }
}

############################
# Glue Table: Tweet Sentiments
############################
# This table captures records produced by sentiment_analysis.py.
# The record includes the original tweet fields plus:
# - sentiment (double)
# - processed_timestamp (the time when the tweet was processed)

resource "aws_glue_catalog_table" "tweet_sentiments" {
  name          = "tweet_sentiments"
  database_name = aws_glue_catalog_database.tweets_database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification  = "json"
    compressionType = "none"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.tweet_sentiments_bucket.bucket}/data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "tweet_sentiments_serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "id"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "text"
      type = "string"
    }
    columns {
      name = "sentiment"
      type = "double"
    }
    columns {
      name = "processed_timestamp"
      type = "string"
    }
  }
}

############################
# Glue Table: Aggregated Tweets
############################
# This table corresponds to the output of streaming_aggregation.py,
# which aggregates data into time windows and writes results to S3.

resource "aws_glue_catalog_table" "aggregated_tweets" {
  name          = "aggregated_tweets"
  database_name = aws_glue_catalog_database.tweets_database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification  = "json"
    compressionType = "none"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.aggregated_bucket.bucket}/aggregated/data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "aggregated_tweets_serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "window_start"
      type = "timestamp"
    }
    columns {
      name = "window_end"
      type = "timestamp"
    }
    columns {
      name = "avg_sentiment"
      type = "double"
    }
  }
}
