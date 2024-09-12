USE ROLE KAMESH_DEMOS_ROLE;
USE WAREHOUSE KAMESH_DEMOS_S;

USE DATABASE KAMESH_LLM_DEMO;
USE SCHEMA DATA;

CREATE OR REPLACE GIT REPOSITORY kamesh_llm_demos
  API_INTEGRATION = kameshs_git_api_integration
  ORIGIN = 'https://github.com/kameshsampath/cortex-llm-demo.git';

ALTER GIT REPOSITORY kamesh_llm_demos FETCH;

-- make sure you get tests.sql and setup.sql files
ls @kamesh_llm_demos/branches/main;