--!jinja
USE ROLE ACCOUNTADMIN;
CREATE ROLE IF NOT EXISTS {{ ROLE }};
GRANT ROLE {{ ROLE }} TO USER {{ USER }};
-- Database that will hold all demo data
CREATE DATABASE IF NOT EXISTS {{ DB }};
CREATE SCHEMA IF NOT EXISTS {{ DB ~ '.' ~ 'INTEGRATIONS' }};
CREATE SCHEMA IF NOT EXISTS {{ DB ~ '.' ~ 'REPOSITORIES' }};
-- GitHub Secret
CREATE OR REPLACE SECRET {{ DB ~ '.INTEGRATIONS' ~ '.' ~ USER ~ '_git_secret' }}
  TYPE = password
  USERNAME = '{{ GITHUB_USER }}'
  PASSWORD = '{{ GITHUB_TOKEN }}';

-- GitHub Integration
CREATE OR REPLACE API INTEGRATION {{ USER ~ '_git_api_integration' }}
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/kameshsampath')
  ALLOWED_AUTHENTICATION_SECRETS = ({{ 'INTEGRATIONS' ~ '.' ~ USER ~'_git_secret' }})
  ENABLED = TRUE;

-- Grants
-- Grant DB Ownerships
GRANT OWNERSHIP ON DATABASE {{ DB }} TO {{ ROLE }};
GRANT OWNERSHIP ON SCHEMA {{ DB }}.PUBLIC TO {{ ROLE }};
-- Schema to hold all integrations
GRANT OWNERSHIP ON SCHEMA {{ DB ~ '.' ~ 'INTEGRATIONS' }} TO {{ ROLE }};
-- Schema to hold all repositories
GRANT OWNERSHIP ON SCHEMA {{ DB ~ '.' ~ 'REPOSITORIES' }} TO {{ ROLE }};

GRANT OWNERSHIP ON SECRET {{ DB ~ '.INTEGRATIONS' ~ '.' ~ USER ~ '_git_secret' }} TO {{ ROLE }};
GRANT USAGE ON INTEGRATION {{ USER ~ '_git_api_integration' }} TO {{ ROLE }};

-- Grant permissions to create Git repository
GRANT CREATE GIT REPOSITORY ON SCHEMA {{ DB ~ '.' ~ 'REPOSITORIES'}} TO ROLE {{ ROLE }};

USE ROLE {{ ROLE }};
USE DATABASE {{ DB }};
-- Git Repository
CREATE OR REPLACE GIT REPOSITORY REPOSITORIES.cortex_llm_demo
  API_INTEGRATION = {{ USER ~ '_git_api_integration' }}
  GIT_CREDENTIALS = {{ DB ~ '.INTEGRATIONS' ~ '.' ~ USER ~ '_git_secret' }}
  ORIGIN = 'https://github.com/kameshsampath/cortex-llm-demo.git';