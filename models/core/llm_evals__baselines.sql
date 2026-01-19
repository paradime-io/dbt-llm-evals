{{
    config(
        materialized='table',
        tags=['llm_evals', 'core'],
        pre_hook="{{ dbt_llm_evals.ensure_raw_tables_exist() }}"
    )
}}

{%- set eval_schema = dbt_llm_evals.get_package_schema() -%}

-- Check if baseline_version column exists, if not provide default
{% set check_column_sql %}
{% if target.type == 'bigquery' %}
SELECT COUNT(*) as column_count
FROM `{{ eval_schema }}.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'raw_baselines'
  AND column_name = 'baseline_version'
{% elif target.type == 'snowflake' %}
SELECT COUNT(*) as column_count
FROM {{ database }}.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = '{{ eval_schema | upper }}'
  AND table_name = 'RAW_BASELINES'
  AND column_name = 'BASELINE_VERSION'
{% else %}
SELECT 1 as column_count
{% endif %}
{% endset %}

{% if execute %}
  {% set result = run_query(check_column_sql) %}
  {% set has_version_column = result.rows[0][0] > 0 if result else false %}
{% else %}
  {% set has_version_column = true %}
{% endif %}

SELECT
    baseline_id,
    source_model,
    {% if has_version_column %}
    baseline_version,
    {% else %}
    'v1.0' as baseline_version,
    {% endif %}
    baseline_input,
    baseline_output,
    baseline_created_at,
    dbt_invocation_id,
    is_active
FROM {{ eval_schema }}.raw_baselines
ORDER BY source_model, baseline_created_at DESC
