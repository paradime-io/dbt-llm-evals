{{
    config(
        materialized='table',
        tags=['llm_evals', 'monitoring', 'alerting']
    )
}}

with drift_alerts as (
    select
        source_model,
        criterion,
        'drift_detection' as alert_type,
        drift_status as severity,
        drift_message as message,
        score_drift as metric_value,
        calculated_at as alert_timestamp
    from {{ ref('llm_evals__drift_detection') }}
    where drift_status in ('ALERT', 'WARNING')
),

performance_alerts as (
    select
        source_model,
        criterion,
        'low_pass_rate' as alert_type,
        case
            when pass_rate < 50 then 'ALERT'
            when pass_rate < 70 then 'WARNING'
        end as severity,
        'Pass rate is ' || round(pass_rate, 1) || '% (threshold: 70%)' as message,
        pass_rate as metric_value,
        calculated_at as alert_timestamp
    from {{ ref('llm_evals__performance_summary') }}
    where pass_rate < 70
        and eval_date >= {{ dbt.dateadd('day', -7, dbt.current_timestamp()) }}
),

confidence_alerts as (
    select
        source_model,
        criterion,
        'low_confidence' as alert_type,
        'WARNING' as severity,
        'Average confidence is ' || round(avg_confidence, 2) || ' (threshold: 0.7)' as message,
        avg_confidence as metric_value,
        calculated_at as alert_timestamp
    from {{ ref('llm_evals__performance_summary') }}
    where avg_confidence < 0.7
        and eval_date >= {{ dbt.dateadd('day', -7, dbt.current_timestamp()) }}
),

parse_error_alerts as (
    select
        source_model,
        criterion,
        'parse_errors' as alert_type,
        case
            when parse_error_count > 10 then 'ALERT'
            else 'WARNING'
        end as severity,
        'Judge returned ' || parse_error_count || ' unparseable responses' as message,
        cast(parse_error_count as {{ dbt.type_float() }}) as metric_value,
        calculated_at as alert_timestamp
    from {{ ref('llm_evals__performance_summary') }}
    where parse_error_count > 0
        and eval_date >= {{ dbt.dateadd('day', -7, dbt.current_timestamp()) }}
),

all_alerts as (
    select * from drift_alerts
    union all
    select * from performance_alerts
    union all
    select * from confidence_alerts
    union all
    select * from parse_error_alerts
)

select
    {{ dbt_utils.generate_surrogate_key(['source_model', 'criterion', 'alert_type', 'alert_timestamp']) }} as alert_id,
    source_model,
    criterion,
    alert_type,
    severity,
    message,
    metric_value,
    alert_timestamp,
    
    -- Priority for triage
    case
        when severity = 'ALERT' then 1
        when severity = 'WARNING' then 2
        else 3
    end as priority,
    
    -- Recommendations
    case
        when alert_type = 'drift_detection' and metric_value < 0 then 'Review recent prompt changes, model updates, or input data quality'
        when alert_type = 'low_pass_rate' then 'Investigate failing samples and consider retraining or prompt engineering'
        when alert_type = 'low_confidence' then 'Review judge responses for ambiguity or unclear evaluation criteria'
        when alert_type = 'parse_errors' then 'Check judge model output format and parsing logic'
        else 'Review evaluation configuration and model performance'
    end as recommended_action
    
from all_alerts
order by priority, alert_timestamp desc
