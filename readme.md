# Bitcoin Social Sentiment Analyzer

The Bitcoin Social Sentiment Analyzer is a data pipeline that generates, analyzes, and visualizes social sentiment from Bitcoin-related tweets. It leverages OpenAI’s language models to both generate creative tweets about Bitcoin and to assess the sentiment of these tweets. Aggregated sentiment data is further processed using Apache Spark (via AWS Glue) and visualized using AWS Quicksight and queried with AWS Athena.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [File Structure](#file-structure)
- [Prerequisites](#prerequisites)
- [Setup & Deployment](#setup--deployment)
- [Usage](#usage)
- [Visualizations](#visualizations)
- [Infrastructure as Code](#infrastructure-as-code)
- [Contributing](#contributing)

---

## Project Overview

This project processes Bitcoin-related tweets through the following steps:
1. **Tweet Generation:**  
   Tweets are generated using OpenAI's GPT models (e.g., GPT-3.5-turbo) to simulate diverse and engaging Bitcoin-related content.  
   - See [tweet_generator.py](glue_scripts\tweet_generator.py) for the production version.

2. **Sentiment Analysis:**  
   The generated tweets are ingested via AWS Kinesis. Each tweet is then processed using OpenAI's models (via a prompt that instructs the model to output a numeric sentiment score between -10.0 and 10.0) to determine its sentiment.  
   - See [sentiment_analysis.py](glue_scripts\sentiment_analysis.py) for the production pipeline.

3. **Streaming Aggregation:**  
   Processed tweets with sentiment scores are aggregated over configurable time windows using Apache Spark (via AWS Glue). The aggregation computes the average sentiment over the window and writes results to an S3 bucket for downstream analysis.  
   - Refer to [streaming_aggregation.py](glue_scripts\streaming_aggregation.py) for the aggregation job.

4. **Visualization & Querying:**  
   - **AWS Quicksight** is used to visualize the aggregated sentiment data.  
   - **AWS Athena** provides an interface to query both raw tweets and sentiment-enhanced tweets stored in S3.

---

## Architecture

The high-level architecture consists of:

- **Tweet Generator:**

  A Python script generates Bitcoin-related tweets using OpenAI's GPT models and streams them to an AWS Kinesis Data Stream.

- **Sentiment Analyzer:**

  A consumer service reads tweets from Kinesis, performs sentiment analysis using OpenAI's API, and writes the enriched data (tweet + sentiment score) to another Kinesis stream.

- **Kinesis Firehose Delivery:**

A Kinesis Firehose delivery stream is configured to continuously ingest both raw tweet data and sentiment-enhanced tweets directly into S3. This ensures robust, scalable data backup and enables near-real-time analytics using AWS Athena.

- **Streaming Aggregation:**

  An AWS Glue job running a PySpark application consumes the sentiment stream, aggregates sentiment scores over defined time windows, and writes the results to S3.

- **Visualization & Querying:**

  AWS Quicksight visualizes aggregated sentiment trends, while AWS Athena allows users to query both raw tweet data and sentiment data.

A simplified architecture diagram might look like:
![Architecture diagram](Misc\diagram.png)


## File Structure

- **Glue Scripts (`glue_scripts/`):**
  - `tweet_generator.py`  
    Generates Bitcoin-related tweets using OpenAI's chat API and streams them to an AWS Kinesis stream.
  
  - `sentiment_analysis.py`  
    Consumes tweets from Kinesis, analyzes sentiment via OpenAI's API (using a numeric scoring prompt), and streams the results to a sentiments stream.

  - `streaming_aggregation.py`  
    A PySpark (AWS Glue) job that aggregates sentiment scores over a specified time window and writes the results to S3 in JSON format.

- **Terraform Files:**  
  *(Note: The following Terraform files are part of the infrastructure as code for setting up AWS resources, though their content is not displayed here.)*
  - `buckets.tf`
  - `glue_jobs.tf`
  - `glue_tables.tf`
  - `kinesis_and_secrets.tf`
  - `variables.tf`

---

## Prerequisites

- **Python:** Version 3.7 or higher.
- **Pip Packages:**  
  - boto3
  - openai
  - pyspark (for running the aggregation job)
  - AWS Glue libraries (if running on AWS Glue)
- **AWS Services:**  
  - AWS Kinesis (for streaming tweets and sentiments)
  - AWS Kinesis Firehose (for delivering both raw and processed tweet data to S3)
  - AWS Secrets Manager (for securely storing API keys)
  - AWS S3 (for storing aggregated data)
  - AWS Glue (for running the Spark streaming aggregation job)
  - AWS Athena (for querying data)
  - AWS Quicksight (for visualization)
- **Terraform:** For deploying AWS infrastructure using the provided Terraform scripts.

---

## Setup & Deployment

1. **Clone the Repository:**

   ```bash
   git clone https://https://github.com/Kallibek/bitcoin-sentiment-analysis-llm-aws.git
   cd bitcoin-sentiment-analysis-llm-aws

2. **Configure AWS Credentials**:
Ensure your AWS credentials are set up in your environment. Also, configure the necessary secrets in Terraform Variables (e.g., OpenAI API key).


3. **Deploy AWS Infrastructure**:
Use Terraform to provision the required AWS resources (Kinesis streams, S3 buckets, Glue jobs, etc.). For example:

    ```bash
    terraform init
    terraform apply
    ```

4. **Run Production Scripts**:
Execute the production scripts with the required parameters. For example:

    ```bash
    aws glue start-job-run --job-name tweet_generator_job

    aws glue start-job-run --job-name sentiment_analysis_job

    aws glue start-job-run --job-name streaming_aggregation_job
    ```
## Usage

* Tweet Generation:

    Tweets are generated periodically (every 5 seconds in the production script) and sent to the Kinesis stream.

* Sentiment Analysis:

    The sentiment analysis service continuously polls for new tweets from the Kinesis stream, processes each tweet using OpenAI's sentiment analysis prompt, and sends the enriched data to another stream.

* Streaming Aggregation:

    The Spark streaming job aggregates the sentiment scores based on a time window (configurable via aggregation_window parameter) and writes aggregated results to S3.

* Data Visualization:

    * Use AWS Quicksight to build dashboards that visualize the aggregated sentiment trends.

    * Use AWS Athena to run queries on the raw tweets and the sentiment-enhanced data stored in S3.

## Visualizations

**Raw Tweets Data (AWS Athena)**

```sql
SELECT 
* 
FROM "tweets_database"."raw_tweets" 
limit 10;
```
![Raw Tweets from Athena](Misc\raw_tweets.png)



**Tweets with Sentiments (AWS Athena)**

```sql
SELECT 
*
FROM "tweets_database"."tweet_sentiments" 
limit 10;
```

The `sentiment` column is generated from the response provided by OpenAI's LLM.

![Tweets with Sentiments from Athena](Misc\tweets_with_sentiments.png)


**Aggregated Sentiment Dashboard (AWS Quicksight)**

![Bitcoin Social Sentiment over time](Misc\Bitcoin_Social_Sentiment_over_time.png)


## Infrastructure as Code
The Terraform scripts provided (e.g., buckets.tf, glue_jobs.tf, glue_tables.tf, kinesis_and_secrets.tf, variables.tf) are used to provision the necessary AWS infrastructure, including:

* S3 buckets for storing aggregated results.
* AWS Glue jobs and tables.
* Kinesis streams for tweets and sentiments.
* Secrets Manager configurations for secure storage of API keys.

Ensure you review and modify the Terraform scripts as needed for your AWS environment before deployment.

## Contributing

Contributions are welcome! If you have suggestions, improvements, or bug fixes, please open an issue or submit a pull request.