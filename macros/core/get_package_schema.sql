{% macro get_package_schema() %}
    {# Get the schema where dbt_llm_evals models should be created #}
    
    {% set custom_schema = var('llm_evals_schema', none) %}
    
    {% if custom_schema %}
        {# Use generate_schema_name with a more complete model context #}
        {# Create a dummy model node with all expected properties #}
        {% set dummy_node = {
            'name': 'llm_evals_raw_tables',
            'schema': custom_schema,
            'database': target.database,
            'config': {'schema': custom_schema},
            'resource_type': 'model',
            'package_name': 'dbt_llm_evals',
            'path': 'models/llm_evals_raw_tables.sql',
            'original_file_path': 'models/llm_evals_raw_tables.sql',
            'unique_id': 'model.dbt_llm_evals.llm_evals_raw_tables',
            'fqn': ['dbt_llm_evals', 'llm_evals_raw_tables'],
            'alias': 'llm_evals_raw_tables',
            'tags': ['llm_evals', 'setup']
        } %}
        {% set generated_schema = generate_schema_name(custom_schema, dummy_node) %}
        {{ return(generated_schema) }}
    {% else %}
        {# Use current target schema which includes any CI prefixes #}
        {{ return(target.schema) }}
    {% endif %}
{% endmacro %}