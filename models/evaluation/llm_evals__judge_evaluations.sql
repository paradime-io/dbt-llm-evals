{{
    config(
        materialized='incremental',
        unique_key='eval_id',
        on_schema_change='append_new_columns',
        tags=['llm_evals', 'evaluation']
    )
}}

with captures as (
    select * 
    from {{ ref('llm_evals__captures') }}
    where eval_status = 'pending'
    {% if is_incremental() %}
        {% if target.type == 'bigquery' %}
        and captured_at > (select coalesce(max(evaluated_at), TIMESTAMP('1900-01-01')) from {{ this }})
        {% else %}
        and captured_at > (select coalesce(max(evaluated_at), '1900-01-01'::timestamp) from {{ this }})
        {% endif %}
    {% endif %}
    limit {{ var('llm_evals_batch_size', 1000) }}
),

-- Get baseline examples for consistency checks
baselines as (
    select
        source_model,
        {% if target.type == 'snowflake' %}
        listagg(
            'Input: ' || cast(baseline_input as string) || 
            '\nOutput: ' || cast(baseline_output as string),
            '\n---\n'
        ) within group (order by baseline_created_at) as baseline_examples
        {% elif target.type == 'bigquery' %}
        string_agg(
            concat(
                'Input: ', TO_JSON_STRING(baseline_input),
                '\nOutput: ', baseline_output
            ),
            '\n---\n'
            order by baseline_created_at
        ) as baseline_examples
        {% elif target.type == 'databricks' %}
        concat_ws(
            '\n---\n',
            collect_list(
                concat(
                    'Input: ', cast(baseline_input as string),
                    '\nOutput: ', baseline_output
                )
            )
        ) as baseline_examples
        {% endif %}
    from {{ ref('llm_evals__baselines') }}
    where is_active = true
    group by source_model
),

-- Cross join with eval criteria
eval_tasks as (
    select
        c.capture_id,
        c.source_model,
        c.input_data,
        c.output_data,
        c.prompt_data,
        c.captured_at,
        {% if target.type == 'snowflake' %}
        cast(criteria.value as string) as criterion,
        {% elif target.type == 'bigquery' %}
        criteria as criterion,
        {% elif target.type == 'databricks' %}
        criteria as criterion,
        {% endif %}
        b.baseline_examples
    from captures c
    {% if target.type == 'snowflake' %}
    cross join lateral flatten(
        input => parse_json('{{ var("llm_evals_criteria", '["accuracy", "relevance"]') }}')
    ) criteria
    left join baselines b on c.source_model = b.source_model
    {% elif target.type == 'bigquery' %}
    cross join unnest({{ var("llm_evals_criteria", '["accuracy", "relevance"]') }}) as criteria
    left join baselines b on c.source_model = b.source_model
    {% elif target.type == 'databricks' %}
    left join baselines b on c.source_model = b.source_model
    lateral view explode(from_json('{{ var("llm_evals_criteria", '["accuracy", "relevance"]') }}', 'array<string>')) as criteria
    {% endif %}
),

-- Build judge prompts
judge_prompts as (
    select
        capture_id,
        source_model,
        criterion,
        {{ dbt_llm_evals.build_judge_prompt(
            'input_data',
            'output_data',
            'criterion',
            'baseline_examples',
            'prompt_data'
        ) }} as judge_prompt,
        captured_at
    from eval_tasks
),

-- Call warehouse AI as judge
judge_responses as (
    select
        capture_id,
        source_model,
        criterion,
        judge_prompt,
        
        -- Warehouse-native AI call
        {{ dbt_llm_evals.llm_evals__ai_complete(
            var('llm_evals_judge_model'),
            'judge_prompt',
            {
                'temperature': var('llm_evals_judge_temperature', 0.0),
                'max_tokens': var('llm_evals_judge_max_tokens', 500)
            }
        ) }} as judge_response,
        
        {{ dbt_llm_evals.llm_evals__current_timestamp() }} as evaluated_at
        
    from judge_prompts
),

-- Parse JSON responses
parsed_json_responses as (
    select
        capture_id,
        source_model,
        criterion,
        judge_prompt,
        judge_response,
        evaluated_at,
        
        -- Parse JSON response
        {{ dbt_llm_evals.llm_evals__parse_json_response('judge_response') }} as parsed_json
        
    from judge_responses
),

-- Extract fields from parsed JSON
parsed_evaluations as (
    select
        capture_id,
        source_model,
        criterion,
        judge_prompt,
        judge_response,
        evaluated_at,
        
        -- Extract fields (warehouse-specific)
        {% if target.type == 'snowflake' %}
        try_cast(cast(parsed_json:score as string) as integer) as score,
        cast(parsed_json:reasoning as string) as reasoning,
        try_cast(cast(parsed_json:confidence as string) as float) as confidence
        
        {% elif target.type == 'bigquery' %}
        safe_cast(json_value(parsed_json, '$.score') as int64) as score,
        json_value(parsed_json, '$.reasoning') as reasoning,
        safe_cast(json_value(parsed_json, '$.confidence') as float64) as confidence
        
        {% elif target.type == 'databricks' %}
        cast(parsed_json.score as int) as score,
        parsed_json.reasoning as reasoning,
        cast(parsed_json.confidence as double) as confidence
        
        {% else %}
        null as score,
        null as reasoning,
        null as confidence
        {% endif %}
        
    from parsed_json_responses
)

select
    {{ dbt_utils.generate_surrogate_key(['capture_id', 'criterion', 'evaluated_at']) }} as eval_id,
    capture_id,
    source_model,
    criterion,
    '{{ var("llm_evals_judge_model") }}' as judge_model,
    
    -- Scores
    score,
    reasoning,
    confidence,
    
    -- Quality flags
    case 
        when score is null then true
        when confidence < 0.5 then true
        when reasoning is null or length(reasoning) < 10 then true
        else false
    end as needs_review,
    
    -- Evaluation result
    case
        when score is null then 'parse_error'
        when score >= {{ var('llm_evals_pass_threshold', 7) }} then 'pass'
        when score >= {{ var('llm_evals_warn_threshold', 5) }} then 'warn'
        else 'fail'
    end as eval_result,
    
    -- Raw data for debugging
    judge_prompt,
    judge_response,
    
    evaluated_at,
    '{{ invocation_id }}' as dbt_invocation_id

from parsed_evaluations
