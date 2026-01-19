{% macro bigquery__llm_evals__ai_complete(model, prompt, options={}) %}
    {%- set temperature = options.get('temperature', var('llm_evals_judge_temperature', 0.0)) -%}
    {%- set max_tokens = options.get('max_tokens', var('llm_evals_judge_max_tokens', 500)) -%}
    {%- set project_id = var('gcp_project_id') -%}
    {%- set location = var('gcp_location') -%}
    {%- set dataset = var('llm_evals_dataset') -%}
    
    AI.GENERATE(
        prompt => {{ prompt }},
        connection_id => '{{ var("ai_connection_id") }}',
        endpoint => '{{ model }}'
    ).result
{% endmacro %}

{% macro bigquery__llm_evals__parse_json_response(response_column) %}
    safe.parse_json({{ response_column }})
{% endmacro %}

{% macro bigquery__llm_evals__ai_classify(text, categories) %}
    {%- set project_id = var('gcp_project_id') -%}
    {%- set dataset = var('llm_evals_dataset') -%}
    
    ML.PREDICT(
        MODEL `{{ project_id }}.{{ dataset }}.text_classifier`,
        (SELECT {{ text }} as content)
    )
{% endmacro %}

{% macro bigquery__llm_evals__current_timestamp() %}
    timestamp(datetime(current_timestamp(), 'UTC'))
{% endmacro %}
