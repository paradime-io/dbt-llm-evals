{{
    config(
        materialized='view',
        tags=['llm_evals', 'monitoring']
    )
}}

with captures as (
    select * from {{ ref('llm_evals__captures') }}
),

evaluations as (
    select
        capture_id,
        count(*) as evaluation_count,
        max(evaluated_at) as latest_evaluation_at,
        min(score) as min_score,
        max(score) as max_score,
        avg(score) as avg_score
    from {{ ref('llm_evals__judge_evaluations') }}
    group by 1
)

select
    c.capture_id,
    c.source_model,
    c.captured_at,
    c.dbt_invocation_id,
    
    -- Status metrics
    case
        when e.evaluation_count > 0 then 'completed'
        else 'pending'
    end as eval_status,
    
    coalesce(e.evaluation_count, 0) as evaluation_count,
    e.latest_evaluation_at,
    
    -- Score summary (if available)
    e.min_score,
    e.max_score,
    e.avg_score,
    
    -- Raw content
    c.input_data,
    c.output_data

from captures c
left join evaluations e on c.capture_id = e.capture_id
