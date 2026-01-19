{% macro snowflake__llm_evals__ai_complete(model, prompt, options={}) %}
    {%- set temperature = options.get('temperature', var('llm_evals_judge_temperature', 0.0)) -%}
    {%- set max_tokens = options.get('max_tokens', var('llm_evals_judge_max_tokens', 500)) -%}
    
    AI_COMPLETE(
        '{{ model }}',
        {{ prompt }},
        object_construct(
            'temperature', {{ temperature }},
            'max_tokens', {{ max_tokens }}
        )
    )
{% endmacro %}

{% macro snowflake__llm_evals__parse_json_response(response_column) %}
    try_parse_json({{ response_column }})
{% endmacro %}

{% macro snowflake__llm_evals__ai_classify(text, categories) %}
    AI_CLASSIFY(
        {{ text }},
        {{ categories }}
    )
{% endmacro %}

{% macro snowflake__llm_evals__current_timestamp() %}
    convert_timezone('UTC', current_timestamp())::timestamp_ntz
{% endmacro %}
