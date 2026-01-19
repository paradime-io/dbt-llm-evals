{% macro check_and_create_baseline(model_relation, input_columns, output_column, baseline_version) %}

    {% set eval_schema = dbt_llm_evals.get_package_schema() %}
    
    {# Check if baseline exists for this version #}
    {% set baseline_check_query %}
        SELECT COUNT(*) as baseline_count
        FROM {% if target.type == 'bigquery' %}`{{ target.database }}.{{ eval_schema }}.raw_baselines`{% elif target.type == 'databricks' %}{{ target.database }}.{{ eval_schema }}.raw_baselines{% else %}{{ eval_schema }}.raw_baselines{% endif %}
        WHERE source_model = '{{ model_relation }}'
          AND is_active = true
          AND baseline_version = '{{ baseline_version }}'
    {% endset %}
    
    {% set result = run_query(baseline_check_query) %}
    {% set baseline_exists = result.rows[0][0] > 0 if result else false %}
    
    {% if not baseline_exists %}
        {{ log("No baseline found for version '" ~ baseline_version ~ "'. Creating baseline with " ~ var('llm_evals_baseline_sample_size', 100) ~ " samples...", info=true) }}
        {{ dbt_llm_evals.create_baseline_snapshot(model_relation, input_columns, output_column, baseline_version) }}
    {% endif %}

{% endmacro %}