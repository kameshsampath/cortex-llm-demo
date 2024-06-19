--!jinja
USE ROLE ACCOUNTADMIN;
CREATE ROLE IF NOT EXISTS {{.ROLE}};
GRANT ROLE {{.ROLE}} TO USER CURRENT_USER;
-- Database that will hold all demo data
CREATE DATABASE IF NOT EXISTS {{.DB}};
CREATE SCHEMA IF NOT EXISTS {{.DB}}.INTEGRATIONS;
CREATE SCHEMA IF NOT EXISTS {{.DB}}.REPOSITORIES;
GRANT OWNERSHIP ON DATABASE {{.DB}} TO {{.ROLE}};
GRANT OWNERSHIP ON SCHEMA {{.DB}}.PUBLIC TO {{.ROLE}};
-- Schema to hold all integrations
GRANT OWNERSHIP ON SCHEMA {{.DB}}.INTEGRATIONS TO {{.ROLE}};
-- Schema to hold all repositories
GRANT OWNERSHIP ON SCHEMA {{.DB}}.REPOSITORIES TO {{.ROLE}};
-- Grant permissions to create Git repository
GRANT CREATE GIT REPOSITORY ON SCHEMA {{.DB}}.INTEGRATIONS TO ROLE {{.ROLE}};
-- Run rest using demo role on demo database

USE ROLE {{.ROLE}};
USE DATABASE {{.DB}};
-- Git Secret
CREATE OR REPLACE SECRET INTEGRATIONS.kameshs_git_secret
  TYPE = password
  USERNAME = 'kameshsampath'
  PASSWORD = '{{.GITHUB_TOKEN}}';

-- GitHub Integration
CREATE OR REPLACE API INTEGRATION INTEGRATIONS.git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/kameshsampath')
  ALLOWED_AUTHENTICATION_SECRETS = (kameshs_git_secret)
  ENABLED = TRUE;

-- Git Repository 
CREATE OR REPLACE GIT REPOSITORY REPOSITORIES.cortex_llm_demo
  API_INTEGRATION = INTEGRATIONS.git_api_integration
  GIT_CREDENTIALS = INTEGRATIONS.kameshs_git_secret
  ORIGIN = 'https://github.com/kameshsampath/cortex-llm-demo.git';