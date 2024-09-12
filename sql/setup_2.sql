USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS KAMESH_LLM_DEMO;

GRANT OWNERSHIP ON DATABASE KAMESH_LLM_DEMO TO ROLE KAMESH_DEMOS_ROLE;

USE WAREHOUSE KAMESH_DEMOS_S;

USE ROLE KAMESH_DEMOS_ROLE;

USE DATABASE KAMESH_LLM_DEMO;

CREATE OR REPLACE SCHEMA DATA;

CREATE OR REPLACE STAGE DOCS 
  encryption = (TYPE = 'SNOWFLAKE_SSE') directory = ( ENABLE = true );

CREATE OR REPLACE STAGE MY_MODELS 
  encryption = (TYPE = 'SNOWFLAKE_SSE') directory = ( ENABLE = true );

CREATE OR REPLACE FUNCTION PDF_TEXT_CHUNKER(FILE_URL STRING)
RETURNS TABLE (CHUNK VARCHAR)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
HANDLER = 'pdf_text_chunker'
PACKAGES = ('snowflake-snowpark-python','PyPDF2', 'langchain')
AS
$$
from snowflake.snowpark.types import StringType, StructField, StructType
from langchain.text_splitter import RecursiveCharacterTextSplitter
from snowflake.snowpark.files import SnowflakeFile
import PyPDF2, io
import logging
import pandas as pd

class pdf_text_chunker:

    def read_pdf(self, file_url: str) -> str:
    
        logger = logging.getLogger("udf_logger")
        logger.info(f"Opening file {file_url}")
    
        with SnowflakeFile.open(file_url, 'rb') as f:
            buffer = io.BytesIO(f.readall())
            
        reader = PyPDF2.PdfReader(buffer)   
        text = ""
        for page in reader.pages:
            try:
                text += page.extract_text().replace('\n', ' ').replace('\0', ' ')
            except:
                text = "Unable to Extract"
                logger.warn(f"Unable to extract from file {file_url}, page {page}")
        
        return text

    def process(self,file_url: str):

        text = self.read_pdf(file_url)
        
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size = 4000, 
            chunk_overlap  = 400, # This let's text have some form of overlap. Useful for keeping chunks contextual
            length_function = len
        )
    
        chunks = text_splitter.split_text(text)
        df = pd.DataFrame(chunks, columns=['chunks'])
        
        yield from df.itertuples(index=False, name=None)
$$;

SHOW TABLES;

CREATE OR REPLACE TABLE DOCS_CHUNKS_TABLE ( 
    RELATIVE_PATH VARCHAR(16777216), -- Relative path to the PDF file
    SIZE NUMBER(38,0), -- Size of the PDF
    FILE_URL VARCHAR(16777216), -- URL for the PDF
    SCOPED_FILE_URL VARCHAR(16777216), -- Scoped url (you can choose which one to keep depending on your use case)
    CHUNK VARCHAR(16777216), -- Piece of text
    CHUNK_VEC VECTOR(FLOAT, 768) );  -- Embedding using the VECTOR data type

CREATE OR REPLACE FILE FORMAT CSVFORMAT
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TYPE = 'CSV';

-- SUPPORT_TICKETS
CREATE OR REPLACE STAGE SUPPORT_TICKETS_DATA_STAGE
  FILE_FORMAT = CSVFORMAT
  URL = 's3://sfquickstarts/finetuning_llm_using_snowflake_cortex_ai/';

CREATE OR REPLACE TABLE SUPPORT_TICKETS (
  TICKET_ID VARCHAR(60),
  CUSTOMER_NAME VARCHAR(60),
  CUSTOMER_EMAIL VARCHAR(60),
  SERVICE_TYPE VARCHAR(60),
  REQUEST VARCHAR,
  CONTACT_PREFERENCE VARCHAR(60)
);

COPY INTO SUPPORT_TICKETS
  FROM @SUPPORT_TICKETS_DATA_STAGE;

-- SUPPORT_TICKETS_FINETUNE
CREATE OR REPLACE STAGE SUPPORT_TICKETS_FINETUNE_DATA_STAGE
  FILE_FORMAT = CSVFORMAT
  URL = 's3://sfquickstarts/snowflake_world_tour_2024_fine_tune/';

CREATE OR REPLACE TABLE SUPPORT_TICKETS_FINETUNE (
	TICKET_ID VARCHAR(60),
	PROMPT VARCHAR(16777216),
	MISTRAL_LARGE_RESPONSE VARCHAR(16777216)
);

COPY INTO SUPPORT_TICKETS_FINETUNE
  FROM @support_tickets_finetune_data_stage;
  
-- SUPPORT_TICKETS_TRAIN
CREATE OR REPLACE STAGE SUPPORT_TICKETS_FINETUNE_TRAIN_DATA_STAGE
  FILE_FORMAT = csvformat
  URL = 's3://sfquickstarts/snowflake_world_tour_2024_fine_tune_train/';

CREATE OR REPLACE TABLE SUPPORT_TICKETS_TRAIN (
	TICKET_ID VARCHAR(60),
	PROMPT VARCHAR(16777216),
	MISTRAL_LARGE_RESPONSE VARCHAR(16777216)
);

COPY INTO SUPPORT_TICKETS_TRAIN
  FROM @SUPPORT_TICKETS_FINETUNE_TRAIN_DATA_STAGE;
  
-- SUPPORT_TICKETS_EVAL
CREATE OR REPLACE STAGE SUPPORT_TICKETS_FINETUNE_EVAL_DATA_STAGE
  FILE_FORMAT = CSVFORMAT
  URL = 's3://sfquickstarts/snowflake_world_tour_2024_fine_tune_eval/';

CREATE OR REPLACE TABLE SUPPORT_TICKETS_EVAL (
	TICKET_ID VARCHAR(60),
	PROMPT VARCHAR(16777216),
	MISTRAL_LARGE_RESPONSE VARCHAR(16777216)
);

COPY INTO SUPPORT_TICKETS_EVAL
  FROM @SUPPORT_TICKETS_FINETUNE_EVAL_DATA_STAGE;

-- CALL TRANSCRIPTS DATA

-- s3 stage to load data files from
CREATE STAGE IF NOT EXISTS  CALL_TRANSCRIPTS_DATA_STAGE
  FILE_FORMAT = CSVFORMAT
  URL = 's3://sfquickstarts/misc/call_transcripts/';

-- table that will be used in LLM queries
CREATE TABLE IF NOT EXISTS CALL_TRANSCRIPTS ( 
  DATE_CREATED DATE,
  LANGUAGE VARCHAR(60),
  COUNTRY VARCHAR(60),
  PRODUCT VARCHAR(60),
  CATEGORY VARCHAR(60),
  DAMAGE_TYPE VARCHAR(90),
  TRANSCRIPT VARCHAR
);

-- Load the data on the transcripts table
COPY INTO CALL_TRANSCRIPTS
  FROM @CALL_TRANSCRIPTS_DATA_STAGE;


