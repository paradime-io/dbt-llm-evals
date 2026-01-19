{{
    config(
        materialized='table',
        tags=['llm_evals', 'core']
    )
}}

with baselines as (
    select * from {{ ref('llm_evals__baselines') }}
),

captures as (
    select * from {{ ref('llm_evals__captures') }}
),

baseline_summary as (
    select
        source_model,
        count(*) as baseline_sample_count,
        min(baseline_created_at) as first_baseline_date,
        max(baseline_created_at) as latest_baseline_date,
        max(case when is_active then baseline_version else null end) as active_baseline_version,
        max(is_active) as has_active_baseline
    from baselines
    group by source_model
),

capture_summary as (
    select
        source_model,
        count(*) as total_captures,
        sum(case when eval_status = 'completed' then 1 else 0 end) as evaluated_count,
        sum(case when eval_status = 'pending' then 1 else 0 end) as pending_count,
        min(captured_at) as first_capture_date,
        max(captured_at) as latest_capture_date
    from captures
    group by source_model
)

select
    coalesce(b.source_model, c.source_model) as source_model,
    
    -- Baseline info
    b.baseline_sample_count,
    b.first_baseline_date,
    b.latest_baseline_date,
    b.active_baseline_version,
    b.has_active_baseline,
    
    -- Capture info
    c.total_captures,
    c.evaluated_count,
    c.pending_count,
    c.first_capture_date,
    c.latest_capture_date,
    
    -- Status
    case
        when b.has_active_baseline = true and c.total_captures > 0 then 'active'
        when b.has_active_baseline = true and c.total_captures = 0 then 'baseline_only'
        when b.has_active_baseline = false and c.total_captures > 0 then 'no_baseline'
        else 'inactive'
    end as status,
    
    current_timestamp as last_updated
    
from baseline_summary b
full outer join capture_summary c
    on b.source_model = c.source_model
