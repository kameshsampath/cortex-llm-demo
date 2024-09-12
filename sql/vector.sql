USE ROLE KAMESH_DEMOS_ROLE;

USE WAREHOUSE KAMESH_DEMOS_S;

USE DATABASE KAMESH_LLM_DEMO;

-- IMP Prerequisites
-- 1) Execute all statements in setup.sql 
-- 2) Use Snowsight to upload all PDFs from data/ folder on `DOCS` stage

USE SCHEMA DATA;

ls @DOCS;

INSERT INTO DOCS_CHUNKS_TABLE (relative_path, size, file_url,
                            scoped_file_url, chunk, chunk_vec)
    SELECT relative_path, 
            size,
            file_url, 
            build_scoped_file_url(@DOCS, relative_path) AS scoped_file_url,
            func.chunk AS chunk,
            snowflake.cortex.embed_text('e5-base-v2',chunk) AS chunk_vec
    FROM 
        directory(@DOCS),
        TABLE(pdf_text_chunker(build_scoped_file_url(@DOCS, relative_path))) AS func;

SELECT relative_path, size, chunk, chunk_vec FROM docs_chunks_table;
SELECT relative_path, count(*) AS num_chunks FROM docs_chunks_table GROUP BY relative_path;
