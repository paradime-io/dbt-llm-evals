{{
    config(
        materialized='table',
        tags=['llm_evals', 'evaluation']
    )
}}

with evaluations as (
    select * from {{ ref('llm_evals__judge_evaluations') }}
),

captures as (
    select * from {{ ref('llm_evals__captures') }}
)

select
    e.eval_id,
    e.capture_id,
    c.source_model,
    c.input_data,
    c.output_data,
    c.captured_at,
    
    e.criterion,
    e.judge_model,
    e.score,
    e.reasoning,
    e.confidence,
    e.needs_review,
    e.eval_result,
    e.evaluated_at,
    e.dbt_invocation_id
    
from evaluations e
inner join captures c
    on e.capture_id = c.capture_id
