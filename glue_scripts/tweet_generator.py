import time
import json
import boto3
from openai import OpenAI
import uuid
from datetime import datetime
from botocore.exceptions import ClientError
import sys
from awsglue.utils import getResolvedOptions

# Initialize Secrets Manager client
secrets_client = boto3.client('secretsmanager')

args = getResolvedOptions(sys.argv, ['openai_secret_id','tweets_stream'])

def get_openai_api_key(secret_id):
    try:
        response = secrets_client.get_secret_value(SecretId=secret_id)
        return response['SecretString']
    except ClientError as e:
        print("Error fetching secret:", e)
        sys.exit(1)

# Retrieve the OpenAI API key using the secret_id argument
OPENAI_API_KEY = get_openai_api_key(args['openai_secret_id'])

# Create a Kinesis client
kinesis_client = boto3.client('kinesis')

# Name of the tweets stream
STREAM_NAME = args['tweets_stream'] #"tweets_stream"

ai_client = OpenAI(api_key=OPENAI_API_KEY)

def generate_fake_tweet():
    """Generate a random fake tweet about Bitcoin using OpenAI's chat completions API."""
    try:
        response = ai_client.chat.completions.create(
            model="gpt-3.5-turbo",  # or use "gpt-4" if available
            messages=[
                {
                    "role": "system",
                    "content": "You are a creative social media bot that generates diverse and engaging tweets about Bitcoin."
                },
                {
                    "role": "user",
                    "content": "Generate a tweet about Bitcoin that is creative, varied in tone, and doesn't always start with the same phrase."
                }
            ],
            max_tokens=50,
            temperature=0.7
        )
        tweet_text = response.choices[0].message.content.strip()
    except Exception as e:
        print("Error generating tweet:", e)
        tweet_text = "Bitcoin is interesting!"

    tweet = {
        "timestamp": datetime.utcnow().isoformat(),
        "text": tweet_text,
        "id": str(uuid.uuid4())
    }
    return tweet

def main():
    """Main loop to send generated tweets to the Kinesis stream."""
    while True:
        tweet = generate_fake_tweet()
        try:
            kinesis_client.put_record(
                StreamName=STREAM_NAME,
                Data=json.dumps(tweet),
                PartitionKey=tweet['id']
            )
            print("Sent tweet:", tweet)
        except Exception as e:
            print("Error sending tweet to Kinesis:", e)
        
        time.sleep(5)  # Wait N seconds before generating the next tweet

if __name__ == "__main__":
    main()