# Demo Script

Modified version of [LLM demo](https://medium.com/snowflake/run-3-useful-llm-inference-jobs-in-minutes-with-snowflake-cortex-743a6096fff8) with updates to LLM Functions, Streamlit.

## Env Setup

```shell
pip install -U requirements.txt
```

## Verify Connection

```shell
snow connection test
```

## Prepare DB

```shell
snow sql -f sql/setup.sql --role='ACCOUNTADMIN'
```

## Load Data

```shell
snow sql -f sql/load.sql
```

Verify loaded data,

```shell
snow sql -q 'SELECT * FROM CALL_TRANSCRIPTS LIMIT 10'
```

## LLM Functions

Supported Models

- Large
  - reka-core (not available on AWS `us-west`)
  - llama3-70b
  - mistral-large
- Medium
  - snowflake-arctic(**default**)
  - reka-flash
  - mixtral-8x7b
  - llama2-70b-chat
- Small
  - llama3-8b
  - mistral-7b
  - gemma-7b

### COMPLETE

```shell
snow cortex complete  'Tell me about Snowflake'
```

### TRANSLATE

```shell
snow cortex translate --from "fr" --to "en" 'Comment allez-vous?'
```

### SENTIMENT

`-1` Negative , `0` Neutral, `1` Positive

```shell
snow sql --stdin <<EOF
SELECT TRANSCRIPT, ROUND(SNOWFLAKE.CORTEX.SENTIMENT(TRANSCRIPT))::INT AS Sentiment
FROM CALL_TRANSCRIPTS
WHERE LANGUAGE = 'English'
LIMIT 10;
EOF
```

### SUMMARIZE

```shell
snow sql --stdin <<EOF
SELECT TRANSCRIPT,SNOWFLAKE.CORTEX.SUMMARIZE(TRANSCRIPT) AS Summary
FROM CALL_TRANSCRIPTS
WHERE LANGUAGE = 'English'
LIMIT 1;
EOF
```

### PROMPTING

```shell
export LLM_PROMPT="Summarize this transcript in less than 200 words.Put the product name, defect and summary in JSON format."
cat <<EOF | snow sql --format json -i
SELECT transcript,SNOWFLAKE.CORTEX.COMPLETE('snowflake-arctic',CONCAT('[INST]','${LLM_PROMPT}',transcript,'[/INST]')) AS Summary
FROM CALL_TRANSCRIPTS WHERE LANGUAGE = 'English'
LIMIT 1;
EOF
```

### Extract Answer

Use the [Answers](./samples/answers.txt) to answer [questions](./samples/questions.txt)

```shell
snow cortex extract-answer --file ./samples/answers.txt 'what does snowpark do ?'
```

```shell
snow cortex extract-answer --file ./samples/answers.txt 'What does Snowflake eliminate?'
```

```shell
snow cortex extract-answer --file ./samples/answers.txt 'What non-SQL code Snowpark process?'
```

### Streamlit App

```shell
streamlit run app.py
```

## Useful Links

- [Snow CLI](https://github.com/snowflakedb/snowflake-cli)
- [Snowflake Trial](https://signup.snowflake.com/)
