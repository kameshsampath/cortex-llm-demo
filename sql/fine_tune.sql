USE ROLE KAMESH_DEMOS_ROLE;

USE WAREHOUSE KAMESH_DEMOS_S;

USE DATABASE KAMESH_LLM_DEMO;

USE SCHEMA DATA;

-- IMP Prerequisites
-- 1) Execute all statements in setup.sql 
-- 2) Use Snowsight to upload all PDFs from data/ folder on `DOCS` stage
-- 3) Execute all statements in vector.sql 

-- Fine-tune mistral-7b model
SELECT snowflake.cortex.finetune(
    'CREATE', 
    'SUPPORT_TICKETS_FINETUNED_MISTRAL_7B', 'mistral-7b', 
    'SELECT prompt, mistral_large_response as completion from KAMESH_LLM_DEMO.DATA.support_tickets_train', 
    'SELECT prompt, mistral_large_response as completion from KAMESH_LLM_DEMO.DATA.support_tickets_eval'
);

-- Check fine-tuning status/progress
-- TODO: Copy job id from the Results and set it in fine_tuned_model_id variable below to check the status
SET fine_tuned_model_id = 'CortexFineTuningWorkflow_71eb6661-8bf8-4aee-ad45-64331f2d1200';
SELECT snowflake.cortex.finetune('DESCRIBE',$fine_tuned_model_id);

-- IMP: Before proceeding with the demo, make sure the fine-tuning job completes successfully with progress set to 1.0 and status set to SUCCESS
