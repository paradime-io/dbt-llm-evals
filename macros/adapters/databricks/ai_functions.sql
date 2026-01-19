{% macro databricks__llm_evals__ai_complete(model, prompt, options={}) %}
    {%- set temperature = options.get('temperature', var('llm_evals_judge_temperature', 0.0)) -%}
    {%- set max_tokens = options.get('max_tokens', var('llm_evals_judge_max_tokens', 500)) -%}
    
    ai_query(
        '{{ model }}',
        {{ prompt }},
        named_struct(
            'temperature', {{ temperature }},
            'max_tokens', {{ max_tokens }}
        )
    )
{% endmacro %}

{% macro databricks__llm_evals__parse_json_response(response_column) %}
    from_json(
        {{ response_column }}, 
        'score INT, reasoning STRING, confidence DOUBLE'
    )
{% endmacro %}

{% macro databricks__llm_evals__ai_classify(text, categories) %}
    ai_classify(
        {{ text }},
        array({{ categories }})
    )
{% endmacro %}

{% macro databricks__llm_evals__current_timestamp() %}
    from_utc_timestamp(current_timestamp(), 'UTC')
{% endmacro %}
