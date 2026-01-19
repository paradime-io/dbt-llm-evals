{{
    config(
        materialized='table',
        tags=['llm_evals', 'monitoring', 'reporting']
    )
}}

with evaluations as (
    select * from {{ ref('llm_evals__eval_scores') }}
),

daily_metrics as (
    select
        {% if target.type == 'snowflake' %}
        date_trunc('day', evaluated_at) as eval_date,
        {% elif target.type == 'bigquery' %}
        date_trunc(date(evaluated_at), day) as eval_date,
        {% elif target.type == 'databricks' %}
        date_trunc('day', evaluated_at) as eval_date,
        {% else %}
        cast(evaluated_at as date) as eval_date,
        {% endif %}
        source_model,
        criterion,
        judge_model,
        
        -- Volume metrics
        count(*) as total_evaluations,
        count(distinct capture_id) as unique_captures,
        
        -- Score metrics
        avg(score) as avg_score,
        min(score) as min_score,
        max(score) as max_score,
        {% if target.type in ('snowflake', 'databricks') %}
        stddev(score) as score_stddev,
        percentile_cont(0.5) within group (order by score) as median_score,
        percentile_cont(0.25) within group (order by score) as p25_score,
        percentile_cont(0.75) within group (order by score) as p75_score,
        {% elif target.type == 'bigquery' %}
        stddev(score) as score_stddev,
        approx_quantiles(score, 2)[offset(1)] as median_score,
        approx_quantiles(score, 4)[offset(1)] as p25_score,
        approx_quantiles(score, 4)[offset(3)] as p75_score,
        {% else %}
        stddev(score) as score_stddev,
        null as median_score,
        null as p25_score,
        null as p75_score,
        {% endif %}
        
        -- Pass/fail metrics
        sum(case when eval_result = 'pass' then 1 else 0 end) as pass_count,
        sum(case when eval_result = 'warn' then 1 else 0 end) as warn_count,
        sum(case when eval_result = 'fail' then 1 else 0 end) as fail_count,
        sum(case when eval_result = 'parse_error' then 1 else 0 end) as parse_error_count,
        round(100.0 * sum(case when eval_result = 'pass' then 1 else 0 end) / count(*), 2) as pass_rate,
        
        -- Confidence metrics
        avg(confidence) as avg_confidence,
        min(confidence) as min_confidence,
        sum(case when needs_review then 1 else 0 end) as needs_review_count,
        
        {{ dbt_llm_evals.llm_evals__current_timestamp() }} as calculated_at
        
    from evaluations
    where score is not null
    group by 1, 2, 3, 4
)

select 
    *,
    -- Health score (composite metric)
    case
        when pass_rate >= 90 and avg_confidence >= 0.8 then 'excellent'
        when pass_rate >= 70 and avg_confidence >= 0.6 then 'good'
        when pass_rate >= 50 and avg_confidence >= 0.5 then 'fair'
        else 'poor'
    end as health_status
    
from daily_metrics
order by eval_date desc, source_model, criterion
