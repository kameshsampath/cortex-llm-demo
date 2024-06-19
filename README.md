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
snow stage copy sql/setup.sql @~/scripts/cortex-llm-demo/ --role='ACCOUNTADMIN'
```

Execute the setup,

Login into Snowsight and run the following command(s) on a SQL Worksheet,

> [!NOTE]
> Replace $GITHUB_USER and $GITHUB_PASSWORD with your credentials

```sql
set c_user = CURRENT_USER;
EXECUTE IMMEDIATE FROM @~/scripts/cortex-llm-demo/setup.sql
    USING(USER => $c_user, DB => 'KAMESH_LLM_DEMO', ROLE => 'KAMESH_DEMOS_ROLE',GITHUB_USER => '$GITHUB_USER', GITHUB_TOKEN => '$GITHUB_PASSWORD');
```

> [!WARNING]
> Does not work now due to bug in SNOW CLI
>
> ```shell
> snow stage execute "@~/scripts/cortex-llm-demo/setup.sql" \
>   --variable="DB=KAMESH_LLM_DEMO" \
>   --variable="ROLE=KAMESH_DEMOS_ROLE" \
>   --variable="GITHUB_USER=$GITHUB_USER" \
>   --variable="GITHUB_TOKEN=$GITHUB_TOKEN" \
>   --role='ACCOUNTADMIN'
> ```

Verify the few objects created as part of setup ,

```sql
SHOW API INTEGRATIONS;
SHOW SECRETS;
SHOW GIT REPOSITORIES;
```

## Load Data

```sql
-- Refresh the repository to fetch latest details
ALTER GIT REPOSITORY REPOSITORIES.cortex_llm_demo FETCH;

-- List files in the repo
ls @REPOSITORIES.cortex_llm_demo/branches/snowsight/sql;

-- Execute the load.sql to load data
-- UPDATE DB/ROLE as needed
EXECUTE IMMEDIATE FROM @REPOSITORIES.cortex_llm_demo/branches/snowsight/sql/load.sql
    USING(DB => 'KAMESH_LLM_DEMO' ,ROLE => 'KAMESH_DEMOS_ROLE');
```

Verify loaded data,

```shell
SELECT * FROM CALL_TRANSCRIPTS LIMIT 10;
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

Navigate to Git Repository on Snowsight and on branch `snowsight` run `fetch` to
update the repository.

You can also open a new SQL worksheet and run the following command to sync your
Git repo. Refer to [docs](https://docs.snowflake.com/en/developer-guide/git/git-operations#refresh-a-repository-stage-from-the-repository) for more details.

```SQL
ALTER GIT REPOSITORY REPOSITORIES.CORTEX_LLM_DEMO FETCH
```

Then navigate to `sql` folder and on click `...` on the row with `cortex.sql` and
do `Copy into Worksheet`. Refer to [docs](https://docs.snowflake.com/en/developer-guide/git/git-operations#copy-repository-based-code-into-a-worksheet) for more details.

You should see a new worksheet with SQL form `cortex.sql` loaded on to a new worksheet.

Try the LLM functions SQL statements to see the Cortex LLM in action.

### Streamlit App

```shell
streamlit run app/app.py
```

## Useful Links

- [Snowflake Trial](https://signup.snowflake.com/)
