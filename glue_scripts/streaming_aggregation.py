from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, window, avg, date_format
from pyspark.sql.types import StructType, StringType, DoubleType, IntegerType, TimestampType
from awsglue.utils import getResolvedOptions
import sys

args = getResolvedOptions(sys.argv, ['aggregation_window', 'output_bucket', 'sentiments_stream'])
aggregation_window = args['aggregation_window']
output_bucket = args['output_bucket']
sentiments_stream = args['sentiments_stream']
# Create Spark session
spark = SparkSession.builder.appName("StreamingAggregation").getOrCreate()

# Define the schema for the sentiment data
schema = StructType() \
    .add("id", IntegerType()) \
    .add("text", StringType()) \
    .add("sentiment", DoubleType()) \
    .add("timestamp", StringType()) \
    .add("processed_timestamp", StringType())

# Read from Kinesis stream (sentiments_stream)
# These options are passed in as job parameters in Glue.
kinesis_options = {
    "streamName": sentiments_stream,
    "endpointUrl": "https://kinesis.us-east-1.amazonaws.com",
    "startingposition": "TRIM_HORIZON"
}

# Read the streaming data from Kinesis.
raw_df = spark \
    .readStream \
    .format("kinesis") \
    .options(**kinesis_options) \
    .load()

# The Kinesis record data is in the "data" column (as bytes); parse it from JSON.
json_df = raw_df.select(from_json(col("data").cast("string"), schema).alias("parsed")).select("parsed.*")

# Convert the processed timestamp from string to a Timestamp type.
# This column will be used for the event time.
json_df = json_df.withColumn("proc_time", col("processed_timestamp").cast(TimestampType()))

# Add a watermark to allow state to be dropped for windows that are already complete.
# Here we assume that late data may be up to 2 minutes late.
streaming_df = json_df.withWatermark("proc_time", "30 seconds")

# Compute average sentiment per hour (window duration is passed in as a job parameter)
agg_df = streaming_df.groupBy(
    window(col("proc_time"), f"{aggregation_window} seconds")
).agg(avg("sentiment").alias("avg_sentiment"))

# For easier downstream processing (or partitioning) we can flatten the window struct.
agg_df = agg_df.withColumn("date", date_format(col("window").start, "yyyy-MM-dd")) \
                .withColumn("window_start", date_format(col("window").start, "yyyy-MM-dd HH:mm:ss")) \
                .withColumn("window_end", date_format(col("window").end, "yyyy-MM-dd HH:mm:ss")) \
                .drop("window")


# Write aggregated results to S3 (output bucket passed in via job parameter)
output_path = f"s3://{output_bucket}/aggregated/"

def write_batch(df, epoch_id):
    if not df.rdd.isEmpty():
        df.write.mode("append") \
            .partitionBy("date") \
            .json(output_path + "data/")

query = agg_df.writeStream \
    .option("checkpointLocation", output_path + "checkpoint/") \
    .foreachBatch(write_batch) \
    .start()

query.awaitTermination()
