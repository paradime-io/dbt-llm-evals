{% macro ensure_raw_tables_exist() %}
    {# This macro ensures that raw_captures and raw_baselines tables exist #}
    {# It's designed to be called as a pre-hook to avoid CI failures #}
    
    {% if execute %}
        {% set eval_schema = dbt_llm_evals.get_package_schema() %}
        
        {# Check if raw_captures table exists #}
        {% set check_captures_table %}
        {% if target.type == 'bigquery' %}
            SELECT COUNT(*) as table_count
            FROM `{{ target.database }}.{{ eval_schema }}`.INFORMATION_SCHEMA.TABLES
            WHERE table_name = 'raw_captures'
        {% elif target.type == 'snowflake' %}
            SELECT COUNT(*) as table_count
            FROM {{ database }}.INFORMATION_SCHEMA.TABLES
            WHERE table_schema = '{{ eval_schema | upper }}'
              AND table_name = 'RAW_CAPTURES'
        {% elif target.type == 'databricks' %}
            SELECT COUNT(*) as table_count
            FROM {{ target.database }}.information_schema.tables
            WHERE table_schema = '{{ eval_schema }}'
              AND table_name = 'raw_captures'
        {% else %}
            SELECT COUNT(*) as table_count
            FROM information_schema.tables
            WHERE table_schema = '{{ eval_schema }}'
              AND table_name = 'raw_captures'
        {% endif %}
        {% endset %}
        
        {% set result = run_query(check_captures_table) %}
        {% set captures_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not captures_exists %}
            {{ log("Raw captures table not found in " ~ eval_schema ~ ". Creating setup tables...", info=true) }}
            
            {# Create schema if it doesn't exist #}
            {% set create_schema_sql %}
                {% if target.type == 'bigquery' %}
                    CREATE SCHEMA IF NOT EXISTS `{{ target.database }}.{{ eval_schema }}`
                {% elif target.type == 'databricks' %}
                    CREATE SCHEMA IF NOT EXISTS {{ target.database }}.{{ eval_schema }}
                {% else %}
                    CREATE SCHEMA IF NOT EXISTS {{ eval_schema }}
                {% endif %}
            {% endset %}
            {% do run_query(create_schema_sql) %}
            
            {# Create the raw_captures table #}
            {% if target.type == 'bigquery' %}
                {% set create_captures_table %}
                CREATE TABLE IF NOT EXISTS `{{ target.database }}.{{ eval_schema }}.raw_captures` (
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
            {% elif target.type == 'snowflake' %}
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
            {% elif target.type == 'databricks' %}
                {% set create_captures_table %}
                CREATE TABLE IF NOT EXISTS {{ target.database }}.{{ eval_schema }}.raw_captures (
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
            {% else %}
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
            {% endif %}
            
            {% do run_query(create_captures_table) %}
            {{ log("✓ Created raw_captures table in schema: " ~ eval_schema, info=true) }}
        {% else %}
            {# Table exists, check if prompt_data column exists and add if missing #}
            {% set check_prompt_column %}
            {% if target.type == 'bigquery' %}
                SELECT COUNT(*) as column_count
                FROM `{{ target.database }}.{{ eval_schema }}`.INFORMATION_SCHEMA.COLUMNS
                WHERE table_name = 'raw_captures'
                  AND column_name = 'prompt_data'
            {% elif target.type == 'snowflake' %}
                SELECT COUNT(*) as column_count
                FROM {{ database }}.INFORMATION_SCHEMA.COLUMNS
                WHERE table_schema = '{{ eval_schema | upper }}'
                  AND table_name = 'RAW_CAPTURES'
                  AND column_name = 'PROMPT_DATA'
            {% elif target.type == 'databricks' %}
                SELECT COUNT(*) as column_count
                FROM {{ target.database }}.information_schema.columns
                WHERE table_schema = '{{ eval_schema }}'
                  AND table_name = 'raw_captures'
                  AND column_name = 'prompt_data'
            {% else %}
                SELECT COUNT(*) as column_count
                FROM information_schema.columns
                WHERE table_schema = '{{ eval_schema }}'
                  AND table_name = 'raw_captures'
                  AND column_name = 'prompt_data'
            {% endif %}
            {% endset %}
            
            {% set result = run_query(check_prompt_column) %}
            {% set prompt_column_exists = result.rows[0][0] > 0 if result else false %}
            
            {% if not prompt_column_exists %}
                {% set add_prompt_column %}
                {% if target.type == 'bigquery' %}
                    ALTER TABLE `{{ eval_schema }}.raw_captures`
                    ADD COLUMN prompt_data STRING
                {% else %}
                    ALTER TABLE {{ eval_schema }}.raw_captures
                    ADD COLUMN prompt_data VARCHAR
                {% endif %}
                {% endset %}
                {% do run_query(add_prompt_column) %}
                {{ log("✓ Added prompt_data column to raw_captures table", info=true) }}
            {% endif %}
        {% endif %}
        
        {# Check if raw_baselines table exists #}
        {% set check_baselines_table %}
        {% if target.type == 'bigquery' %}
            SELECT COUNT(*) as table_count
            FROM `{{ target.database }}.{{ eval_schema }}`.INFORMATION_SCHEMA.TABLES
            WHERE table_name = 'raw_baselines'
        {% elif target.type == 'snowflake' %}
            SELECT COUNT(*) as table_count
            FROM {{ database }}.INFORMATION_SCHEMA.TABLES
            WHERE table_schema = '{{ eval_schema | upper }}'
              AND table_name = 'RAW_BASELINES'
        {% elif target.type == 'databricks' %}
            SELECT COUNT(*) as table_count
            FROM {{ target.database }}.information_schema.tables
            WHERE table_schema = '{{ eval_schema }}'
              AND table_name = 'raw_baselines'
        {% else %}
            SELECT COUNT(*) as table_count
            FROM information_schema.tables
            WHERE table_schema = '{{ eval_schema }}'
              AND table_name = 'raw_baselines'
        {% endif %}
        {% endset %}
        
        {% set result = run_query(check_baselines_table) %}
        {% set baselines_exists = result.rows[0][0] > 0 if result else false %}
        
        {% if not baselines_exists %}
            {# Create the raw_baselines table #}
            {% if target.type == 'bigquery' %}
                {% set create_baselines_table %}
                CREATE TABLE IF NOT EXISTS `{{ target.database }}.{{ eval_schema }}.raw_baselines` (
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
            {% elif target.type == 'snowflake' %}
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
            {% elif target.type == 'databricks' %}
                {% set create_baselines_table %}
                CREATE TABLE IF NOT EXISTS {{ target.database }}.{{ eval_schema }}.raw_baselines (
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
            {% else %}
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
            {% endif %}
            
            {% do run_query(create_baselines_table) %}
            {{ log("✓ Created raw_baselines table in schema: " ~ eval_schema, info=true) }}
        {% else %}
            {# Table exists, check if baseline_version column exists and add if missing #}
            {% set check_version_column %}
            {% if target.type == 'bigquery' %}
                SELECT COUNT(*) as column_count
                FROM `{{ target.database }}.{{ eval_schema }}`.INFORMATION_SCHEMA.COLUMNS
                WHERE table_name = 'raw_baselines'
                  AND column_name = 'baseline_version'
            {% elif target.type == 'snowflake' %}
                SELECT COUNT(*) as column_count
                FROM {{ database }}.INFORMATION_SCHEMA.COLUMNS
                WHERE table_schema = '{{ eval_schema | upper }}'
                  AND table_name = 'RAW_BASELINES'
                  AND column_name = 'BASELINE_VERSION'
            {% elif target.type == 'databricks' %}
                SELECT COUNT(*) as column_count
                FROM {{ target.database }}.information_schema.columns
                WHERE table_schema = '{{ eval_schema }}'
                  AND table_name = 'raw_baselines'
                  AND column_name = 'baseline_version'
            {% else %}
                SELECT COUNT(*) as column_count
                FROM information_schema.columns
                WHERE table_schema = '{{ eval_schema }}'
                  AND table_name = 'raw_baselines'
                  AND column_name = 'baseline_version'
            {% endif %}
            {% endset %}
            
            {% set result = run_query(check_version_column) %}
            {% set version_column_exists = result.rows[0][0] > 0 if result else false %}
            
            {% if not version_column_exists %}
                {% if target.type == 'bigquery' %}
                    {# BigQuery requires separate steps for adding column with default #}
                    {% set add_version_column %}
                    ALTER TABLE `{{ eval_schema }}.raw_baselines`
                    ADD COLUMN baseline_version STRING
                    {% endset %}
                    
                    {% set set_default %}
                    ALTER TABLE `{{ eval_schema }}.raw_baselines`
                    ALTER COLUMN baseline_version SET DEFAULT 'v1.0'
                    {% endset %}
                    
                    {% set update_existing %}
                    UPDATE `{{ eval_schema }}.raw_baselines`
                    SET baseline_version = 'v1.0'
                    WHERE baseline_version IS NULL
                    {% endset %}
                    
                    {% do run_query(add_version_column) %}
                    {% do run_query(set_default) %}
                    {% do run_query(update_existing) %}
                {% else %}
                    {% set add_version_column %}
                    ALTER TABLE {{ eval_schema }}.raw_baselines
                    ADD COLUMN baseline_version VARCHAR
                    {% endset %}
                    
                    {% set update_existing %}
                    UPDATE {{ eval_schema }}.raw_baselines
                    SET baseline_version = 'v1.0'
                    WHERE baseline_version IS NULL
                    {% endset %}
                    
                    {% do run_query(add_version_column) %}
                    {% do run_query(update_existing) %}
                {% endif %}
                {{ log("✓ Added baseline_version column to raw_baselines table", info=true) }}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}