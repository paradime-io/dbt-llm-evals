{{
    config(
        materialized='incremental',
        unique_key='capture_id',
        on_schema_change='append_new_columns',
        tags=['llm_evals', 'core'],
        pre_hook="{{ dbt_llm_evals.ensure_raw_tables_exist() }}"
    )
}}

{%- set eval_schema = dbt_llm_evals.get_package_schema() -%}

with raw_captures as (
    select *
    from {{ eval_schema }}.raw_captures
    
    {% if is_incremental() %}
    where captured_at > (select coalesce(max(captured_at), 
        cast('1900-01-01' as timestamp)
    ) from {{ this }})
    {% endif %}
)

select
    c.capture_id,
    c.source_model,
    c.input_data,
    c.output_data,
    coalesce(c.prompt_data, cast(null as string)) as prompt_data,
    c.captured_at,
    c.dbt_invocation_id,
    
    'pending' as eval_status,
    cast(null as timestamp) as evaluated_at
    
from raw_captures c
