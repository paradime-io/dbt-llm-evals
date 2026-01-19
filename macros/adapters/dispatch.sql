{% macro llm_evals__ai_complete(model, prompt, options={}) %}
    {{ return(adapter.dispatch('llm_evals__ai_complete', 'dbt_llm_evals')(model, prompt, options)) }}
{% endmacro %}

{% macro llm_evals__parse_json_response(response_column) %}
    {{ return(adapter.dispatch('llm_evals__parse_json_response', 'dbt_llm_evals')(response_column)) }}
{% endmacro %}

{% macro llm_evals__ai_classify(text, categories) %}
    {{ return(adapter.dispatch('llm_evals__ai_classify', 'dbt_llm_evals')(text, categories)) }}
{% endmacro %}

{% macro llm_evals__current_timestamp() %}
    {{ return(adapter.dispatch('llm_evals__current_timestamp', 'dbt_llm_evals')()) }}
{% endmacro %}

{# Default implementations - will be overridden by warehouse-specific versions #}
{% macro default__llm_evals__current_timestamp() %}
    current_timestamp()
{% endmacro %}
