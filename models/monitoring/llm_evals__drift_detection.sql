{{
    config(
        materialized='table',
        tags=['llm_evals', 'monitoring', 'alerting']
    )
}}

{%- set lookback_days = var('llm_evals_drift_lookback_days', 7) -%}
{%- set stddev_threshold = var('llm_evals_drift_stddev_threshold', 2) -%}

with evaluations as (
    select * from {{ ref('llm_evals__eval_scores') }}
),

-- Calculate baseline metrics from historical data
baseline_scores as (
    select
        source_model,
        criterion,
        avg(score) as baseline_avg_score,
        stddev(score) as baseline_stddev,
        min(score) as baseline_min_score,
        max(score) as baseline_max_score,
        {% if target.type in ('snowflake', 'databricks') %}
        percentile_cont(0.05) within group (order by score) as p5_score,
        percentile_cont(0.95) within group (order by score) as p95_score,
        {% elif target.type == 'bigquery' %}
        approx_quantiles(score, 20)[offset(1)] as p5_score,
        approx_quantiles(score, 20)[offset(19)] as p95_score,
        {% else %}
        null as p5_score,
        null as p95_score,
        {% endif %}
        count(*) as baseline_sample_size,
        min(evaluated_at) as baseline_start,
        max(evaluated_at) as baseline_end
    from evaluations
    where evaluated_at <= cast({{ dbt.dateadd('day', -lookback_days, dbt.current_timestamp()) }} as timestamp)
        and score is not null
    group by 1, 2
),

-- Calculate recent metrics
recent_scores as (
    select
        source_model,
        criterion,
        avg(score) as recent_avg_score,
        stddev(score) as recent_stddev,
        min(score) as recent_min_score,
        max(score) as recent_max_score,
        count(*) as recent_sample_size,
        min(evaluated_at) as recent_start,
        max(evaluated_at) as recent_end
    from evaluations
    where evaluated_at >= cast({{ dbt.dateadd('day', -lookback_days, dbt.current_timestamp()) }} as timestamp)
        and score is not null
    group by 1, 2
),

-- Compare baseline vs recent
drift_analysis as (
    select
        r.source_model,
        r.criterion,
        
        -- Baseline metrics
        b.baseline_avg_score,
        b.baseline_stddev,
        b.baseline_min_score,
        b.baseline_max_score,
        b.p5_score as baseline_p5,
        b.p95_score as baseline_p95,
        b.baseline_sample_size,
        b.baseline_start,
        b.baseline_end,
        
        -- Recent metrics
        r.recent_avg_score,
        r.recent_stddev,
        r.recent_min_score,
        r.recent_max_score,
        r.recent_sample_size,
        r.recent_start,
        r.recent_end,
        
        -- Drift calculations
        r.recent_avg_score - b.baseline_avg_score as score_drift,
        abs(r.recent_avg_score - b.baseline_avg_score) / nullif(b.baseline_stddev, 0) as drift_in_stddevs,
        
        -- Detect anomalies
        case 
            when r.recent_avg_score < b.p5_score then 'low_score_anomaly'
            when r.recent_avg_score > b.p95_score then 'high_score_anomaly'
            when abs(r.recent_avg_score - b.baseline_avg_score) > {{ stddev_threshold }} * b.baseline_stddev then 'stddev_anomaly'
            else null
        end as anomaly_type,
        
        -- Drift status
        case
            when b.baseline_sample_size < 10 then 'insufficient_baseline'
            when r.recent_sample_size < 5 then 'insufficient_recent_data'
            when abs(r.recent_avg_score - b.baseline_avg_score) > {{ stddev_threshold }} * b.baseline_stddev then 'ALERT'
            when abs(r.recent_avg_score - b.baseline_avg_score) > b.baseline_stddev then 'WARNING'
            else 'OK'
        end as drift_status,
        
        -- Change percentage
        round(100.0 * (r.recent_avg_score - b.baseline_avg_score) / nullif(b.baseline_avg_score, 0), 2) as pct_change,
        
        {{ dbt_llm_evals.llm_evals__current_timestamp() }} as calculated_at
        
    from recent_scores r
    left join baseline_scores b
        on r.source_model = b.source_model
        and r.criterion = b.criterion
)

select
    *,
    -- Priority for alerting
    case
        when drift_status = 'ALERT' then 1
        when drift_status = 'WARNING' then 2
        when drift_status = 'OK' then 3
        else 4
    end as alert_priority,
    
    -- Human-readable message
    case
        when drift_status = 'insufficient_baseline' then 'Not enough baseline data (need 10+ samples)'
        when drift_status = 'insufficient_recent_data' then 'Not enough recent data (need 5+ samples)'
        when drift_status = 'ALERT' and score_drift < 0 then 'ALERT: Significant score drop detected (' || round(score_drift, 2) || ' points)'
        when drift_status = 'ALERT' and score_drift > 0 then 'ALERT: Significant score increase detected (' || round(score_drift, 2) || ' points)'
        when drift_status = 'WARNING' and score_drift < 0 then 'WARNING: Score decline detected (' || round(score_drift, 2) || ' points)'
        when drift_status = 'WARNING' and score_drift > 0 then 'WARNING: Score increase detected (' || round(score_drift, 2) || ' points)'
        else 'No significant drift detected'
    end as drift_message
    
from drift_analysis
order by alert_priority, source_model, criterion
