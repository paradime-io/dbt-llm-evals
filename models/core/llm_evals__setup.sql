{{
    config(
        materialized='view',
        tags=['llm_evals', 'setup']
    )
}}

-- This model creates the necessary raw storage tables
-- Run once: dbt run --select llm_evals__setup

{% if execute %}
    {# Use dbt's native schema resolution with proper model context #}
    {% set eval_schema = dbt_llm_evals.get_package_schema() %}
    
    {# Log which schema we're using for debugging #}
    {{ log("Creating raw tables in schema: " ~ eval_schema, info=true) }}
    
    {# Create schema if it doesn't exist #}
    {% set create_schema_sql %}
    CREATE SCHEMA IF NOT EXISTS {{ eval_schema }}
    {% endset %}
    {% do run_query(create_schema_sql) %}
    
    {% if target.type == 'bigquery' %}
        {# BigQuery specific table creation with baseline_version #}
        {% set create_captures_table %}
        CREATE TABLE IF NOT EXISTS `{{ eval_schema }}.raw_captures` (
            capture_id STRING,
            source_model STRING,
            input_data STRING,
            output_data STRING,
            prompt_data STRING,
            captured_at TIMESTAMP,
            dbt_invocation_id STRING,
            eval_status STRING,
            evaluated_at TIMESTAMP
        )
        {% endset %}
        
        {% set create_baselines_table %}
        CREATE TABLE IF NOT EXISTS `{{ eval_schema }}.raw_baselines` (
            baseline_id STRING,
            source_model STRING,
            baseline_version STRING DEFAULT 'v1.0',
            baseline_input STRING,
            baseline_output STRING,
            baseline_created_at TIMESTAMP,
            dbt_invocation_id STRING,
            is_active BOOL
        )
        {% endset %}
        
        {% do run_query(create_captures_table) %}
        {% do run_query(create_baselines_table) %}
        
        {# Add prompt_data column if it doesn't exist - BigQuery approach #}
        {% set check_prompt_column %}
        SELECT COUNT(*) as column_count
        FROM `{{ eval_schema }}.INFORMATION_SCHEMA.COLUMNS`
        WHERE table_name = 'raw_captures'
          AND column_name = 'prompt_data'
        {% endset %}
        
        {% set result = run_query(check_prompt_column) %}
        {% set prompt_column_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not prompt_column_exists %}
          {% set add_prompt_column %}
          ALTER TABLE `{{ eval_schema }}.raw_captures`
          ADD COLUMN prompt_data STRING
          {% endset %}
          {% do run_query(add_prompt_column) %}
          {{ log("✓ Added prompt_data column to raw_captures table", info=true) }}
        {% endif %}
        
        {# Try to add baseline_version column if table exists without it #}
        {# BigQuery requires separate steps for adding column with default #}
        {% set check_column_exists %}
        SELECT COUNT(*) as column_count
        FROM `{{ eval_schema }}.INFORMATION_SCHEMA.COLUMNS`
        WHERE table_name = 'raw_baselines'
          AND column_name = 'baseline_version'
        {% endset %}
        
        {% set result = run_query(check_column_exists) %}
        {% set column_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not column_exists %}
          {# Step 1: Add the column #}
          {% set add_column %}
          ALTER TABLE `{{ eval_schema }}.raw_baselines`
          ADD COLUMN baseline_version STRING
          {% endset %}
          
          {# Step 2: Set default value for column #}
          {% set set_default %}
          ALTER TABLE `{{ eval_schema }}.raw_baselines`
          ALTER COLUMN baseline_version SET DEFAULT 'v1.0'
          {% endset %}
          
          {# Step 3: Update existing records #}
          {% set update_existing %}
          UPDATE `{{ eval_schema }}.raw_baselines`
          SET baseline_version = 'v1.0'
          WHERE baseline_version IS NULL
          {% endset %}
          
          {% do run_query(add_column) %}
          {% do run_query(set_default) %}
          {% do run_query(update_existing) %}
          
          {{ log("✓ Added baseline_version column to existing raw_baselines table", info=true) }}
        {% endif %}
        
    {% elif target.type == 'snowflake' %}
        {# Snowflake specific #}
        {% set create_captures_table %}
        CREATE TABLE IF NOT EXISTS {{ eval_schema }}.raw_captures (
            capture_id VARCHAR,
            source_model VARCHAR,
            input_data VARIANT,
            output_data VARCHAR,
            prompt_data VARCHAR,
            captured_at TIMESTAMP,
            dbt_invocation_id VARCHAR,
            eval_status VARCHAR,
            evaluated_at TIMESTAMP
        )
        {% endset %}
        
        {% set create_baselines_table %}
        CREATE TABLE IF NOT EXISTS {{ eval_schema }}.raw_baselines (
            baseline_id VARCHAR,
            source_model VARCHAR,
            baseline_version VARCHAR DEFAULT 'v1.0',
            baseline_input VARIANT,
            baseline_output VARCHAR,
            baseline_created_at TIMESTAMP,
            dbt_invocation_id VARCHAR,
            is_active BOOLEAN
        )
        {% endset %}
        
        {% do run_query(create_captures_table) %}
        {% do run_query(create_baselines_table) %}
        
        {# Add prompt_data column if it doesn't exist - Snowflake approach #}
        {% if target.type == 'snowflake' %}
        {% set check_prompt_column %}
        SELECT COUNT(*) as column_count
        FROM {{ database }}.INFORMATION_SCHEMA.COLUMNS
        WHERE table_schema = '{{ eval_schema | upper }}'
          AND table_name = 'RAW_CAPTURES'
          AND column_name = 'PROMPT_DATA'
        {% endset %}
        
        {% set result = run_query(check_prompt_column) %}
        {% set prompt_column_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not prompt_column_exists %}
          {% set add_prompt_column %}
          ALTER TABLE {{ eval_schema }}.raw_captures
          ADD COLUMN prompt_data VARCHAR
          {% endset %}
          {% do run_query(add_prompt_column) %}
          {{ log("✓ Added prompt_data column to raw_captures table", info=true) }}
        {% endif %}
        {% endif %}
        
    {% elif target.type == 'databricks' %}
        {# Databricks specific #}
        {% set create_captures_table %}
        CREATE TABLE IF NOT EXISTS {{ eval_schema }}.raw_captures (
            capture_id STRING,
            source_model STRING,
            input_data STRING,
            output_data STRING,
            prompt_data STRING,
            captured_at TIMESTAMP,
            dbt_invocation_id STRING,
            eval_status STRING,
            evaluated_at TIMESTAMP
        )
        {% endset %}
        
        {% set create_baselines_table %}
        CREATE TABLE IF NOT EXISTS {{ eval_schema }}.raw_baselines (
            baseline_id STRING,
            source_model STRING,
            baseline_version STRING,
            baseline_input STRING,
            baseline_output STRING,
            baseline_created_at TIMESTAMP,
            dbt_invocation_id STRING,
            is_active BOOLEAN
        )
        {% endset %}
        
        {% do run_query(create_captures_table) %}
        {% do run_query(create_baselines_table) %}
        
        {# Add prompt_data column if it doesn't exist - Databricks approach #}
        {% set check_prompt_column %}
        SELECT COUNT(*) as column_count
        FROM information_schema.columns
        WHERE table_schema = '{{ eval_schema.split('.')[1] if '.' in eval_schema else eval_schema }}'
          AND table_name = 'raw_captures'
          AND column_name = 'prompt_data'
        {% endset %}
        
        {% set result = run_query(check_prompt_column) %}
        {% set prompt_column_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not prompt_column_exists %}
          {% set add_prompt_column %}
          ALTER TABLE {{ eval_schema }}.raw_captures
          ADD COLUMN prompt_data STRING
          {% endset %}
          {% do run_query(add_prompt_column) %}
          {{ log("✓ Added prompt_data column to raw_captures table", info=true) }}
        {% endif %}
        
        {# Check if baseline_version column exists and add it if it doesn't #}
        {% set check_column_exists %}
        SELECT COUNT(*) as column_count
        FROM information_schema.columns
        WHERE table_schema = '{{ eval_schema.split('.')[1] if '.' in eval_schema else eval_schema }}'
          AND table_name = 'raw_baselines'
          AND column_name = 'baseline_version'
        {% endset %}
        
        {% set result = run_query(check_column_exists) %}
        {% set column_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not column_exists %}
          {% set add_version_column %}
          ALTER TABLE {{ eval_schema }}.raw_baselines
          ADD COLUMN baseline_version STRING
          {% endset %}
          
          {% set update_existing %}
          UPDATE {{ eval_schema }}.raw_baselines
          SET baseline_version = 'v1.0'
          WHERE baseline_version IS NULL
          {% endset %}
          
          {% do run_query(add_version_column) %}
          {% do run_query(update_existing) %}
          
          {{ log("✓ Added baseline_version column to existing raw_baselines table", info=true) }}
        {% endif %}
        
    {% else %}
        {# Generic fallback #}
        {% set create_captures_table %}
        CREATE TABLE IF NOT EXISTS {{ eval_schema }}.raw_captures (
            capture_id VARCHAR,
            source_model VARCHAR,
            input_data VARCHAR,
            output_data VARCHAR,
            prompt_data VARCHAR,
            captured_at TIMESTAMP,
            dbt_invocation_id VARCHAR,
            eval_status VARCHAR,
            evaluated_at TIMESTAMP
        )
        {% endset %}
        
        {% set create_baselines_table %}
        CREATE TABLE IF NOT EXISTS {{ eval_schema }}.raw_baselines (
            baseline_id VARCHAR,
            source_model VARCHAR,
            baseline_version VARCHAR,
            baseline_input VARCHAR,
            baseline_output VARCHAR,
            baseline_created_at TIMESTAMP,
            dbt_invocation_id VARCHAR,
            is_active BOOLEAN
        )
        {% endset %}
        
        {% do run_query(create_captures_table) %}
        {% do run_query(create_baselines_table) %}
        
        {# Add prompt_data column if it doesn't exist - Generic approach #}
        {% set check_prompt_column %}
        SELECT COUNT(*) as column_count
        FROM information_schema.columns
        WHERE table_schema = '{{ eval_schema }}'
          AND table_name = 'raw_captures'
          AND column_name = 'prompt_data'
        {% endset %}
        
        {% set result = run_query(check_prompt_column) %}
        {% set prompt_column_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not prompt_column_exists %}
          {% set add_prompt_column %}
          ALTER TABLE {{ eval_schema }}.raw_captures
          ADD COLUMN prompt_data VARCHAR
          {% endset %}
          {% do run_query(add_prompt_column) %}
          {{ log("✓ Added prompt_data column to raw_captures table", info=true) }}
        {% endif %}
        
    {% endif %}
    
    {{ log("✓ Created/updated raw_captures and raw_baselines tables in schema: " ~ eval_schema, info=true) }}
    
{% endif %}

-- Return empty result set
SELECT 
    'Setup complete' as status,
    '{{ eval_schema }}' as schema_name,
    {{ dbt_llm_evals.llm_evals__current_timestamp() }} as setup_at
FROM (SELECT 1 as dummy)
WHERE 1=0
