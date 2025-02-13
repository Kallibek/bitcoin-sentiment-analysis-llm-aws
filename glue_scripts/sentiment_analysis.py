import sys, json, boto3, time
from botocore.exceptions import ClientError
import sys
from awsglue.utils import getResolvedOptions
from openai import OpenAI

args = getResolvedOptions(sys.argv, ['openai_secret_id', 'tweets_stream', 'sentiments_stream'])


# Set up boto3 clients
kinesis_client = boto3.client('kinesis')
secrets_client = boto3.client('secretsmanager')
tweets_stream = args['tweets_stream']
sentiments_stream = args['sentiments_stream']

def get_openai_api_key(secret_id):
    try:
        response = secrets_client.get_secret_value(SecretId=secret_id)
        return response['SecretString']
    except ClientError as e:
        print("Error fetching secret:", e)
        sys.exit(1)

OPENAI_API_KEY = get_openai_api_key(args['openai_secret_id'])

ai_client = OpenAI(api_key=OPENAI_API_KEY)

def call_openai_for_sentiment(text):
    """
    Analyze the sentiment of the provided tweet text using OpenAI's API.
    Returns a numeric sentiment score between -10.0 (very negative) and 10.0 (very positive).
    """
    # Construct a prompt that instructs the model to provide a numeric sentiment score.
    prompt = (
        "You are a sentiment analysis tool. Given the tweet text below, output only a single numeric sentiment score "
        "on a scale from -10.0 to 10.0, where -10.0 represents extremely negative sentiment, 0 is neutral, "
        "and 10.0 represents extremely positive sentiment.\n\n"
        "Tweet: " + text + "\n\n"
        "Sentiment score:"
    )
    
    try:
        # Call the OpenAI Completion API with the correct parameter names.
        response = ai_client.completions.create(
            model="davinci-002",
            prompt=prompt,
            max_tokens=20,
            temperature=0.2,
            top_p=1.0,
            frequency_penalty=0.0,
            presence_penalty=0.0,
            stop=["\n"]
        )
        
        # Extract and clean the sentiment score from the response.
        sentiment_score_str = response.choices[0].text.strip()
        sentiment_score = float(sentiment_score_str)
    except Exception as e:
        print("Error calling OpenAI for sentiment analysis:", e)
        sentiment_score = 0.0  # Fallback sentiment score in case of error
    
    return sentiment_score

# Global shard iterator to maintain our position in the stream.
global_shard_iterator = None

def get_tweet():
    """
    Retrieve a single tweet record from the 'tweets_stream' Kinesis data stream.
    
    This function initializes a shard iterator (using the first shard found in the stream)
    and then continuously polls for new records, returning the first available tweet.
    """
    global global_shard_iterator
    if not global_shard_iterator:
        # Initialize the shard iterator for the first shard in the stream.
        try:
            response = kinesis_client.describe_stream(StreamName=tweets_stream)
            shards = response['StreamDescription']['Shards']
            if not shards:
                print("No shards found in stream", tweets_stream)
                return None
            shard_id = shards[0]['ShardId']
            shard_iterator_response = kinesis_client.get_shard_iterator(
                StreamName=tweets_stream,
                ShardId=shard_id,
                ShardIteratorType='LATEST'  # You might choose 'TRIM_HORIZON' or another type as needed.
            )
            global_shard_iterator = shard_iterator_response['ShardIterator']
        except Exception as e:
            print("Error initializing shard iterator:", e)
            time.sleep(1)
            return None

    # Continuously poll the stream until a record is found.
    while True:
        try:
            response = kinesis_client.get_records(ShardIterator=global_shard_iterator, Limit=1)
            global_shard_iterator = response['NextShardIterator']
            records = response.get('Records', [])
            if records:
                # Assuming that the Data field is a JSON string.
                tweet = json.loads(records[0]['Data'])
                return tweet
            else:
                # No records yet; wait a short while before polling again.
                time.sleep(1)
        except Exception as e:
            print("Error reading from Kinesis stream:", e)
            time.sleep(1)

def process_tweet():
    """
    Retrieve one tweet from Kinesis, perform sentiment analysis, and write the result to the output stream.
    """
    tweet = get_tweet()
    if tweet is None:
        print("No tweet retrieved from the stream.")
        return

    sentiment = call_openai_for_sentiment(tweet['text'])
    tweet['sentiment'] = sentiment
    tweet['processed_timestamp'] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    
    # Write the processed tweet with its sentiment score to the output Kinesis stream.
    try:
        kinesis_client.put_record(
            StreamName=sentiments_stream,
            Data=json.dumps(tweet),
            PartitionKey=str(tweet['id'])
        )
        print(f"Processed tweet {tweet['id']} with sentiment {sentiment}")
    except Exception as e:
        print("Error writing to output stream:", e)

def main():
    while True:
        process_tweet()
        time.sleep(1)
        
        

if __name__ == "__main__":
    main()
