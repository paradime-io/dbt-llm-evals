-- Automatic baseline detection - no more manual baseline_mode toggling!

{% macro capture_and_evaluate() %}

{% if execute %}
    {% set model_meta = model.meta.get('llm_evals', {}) %}
    
    {% if model_meta.get('enabled', false) %}
        
        {% set input_cols = model_meta.get('input_columns', []) %}
        {% set output_col = model_meta.get('output_column') %}
        {% set prompt_text = model_meta.get('prompt', none) %}
        {% set sampling_rate = model_meta.get('sampling_rate', var('llm_evals_sampling_rate', 1.0)) %}
        {% set force_rebaseline = model_meta.get('force_rebaseline', false) %}
        {% set baseline_version = model_meta.get('baseline_version', 'v1.0') %}
        {# Use the package's resolved schema (same as dbt_llm_evals models) #}
        {% set eval_schema = dbt_llm_evals.get_package_schema() %}
        
        {# Ensure storage tables exist before any queries #}
        {{ dbt_llm_evals.ensure_raw_tables_exist() }}
        
        {% if not input_cols or not output_col %}
            {{ exceptions.raise_compiler_error("llm_evals requires 'input_columns' and 'output_column' in meta config") }}
        {% endif %}
        
        {# Check if we need to create a new baseline #}
        {% if force_rebaseline %}
            {# User explicitly requested rebaseline #}
            {{ log("Force rebaseline requested. Creating new baseline (version: " ~ baseline_version ~ ")...", info=true) }}
            {{ dbt_llm_evals.create_baseline_snapshot(this, input_cols, output_col, baseline_version) }}
        {% else %}
            {# Check if baseline version exists, create if new version specified #}
            {{ dbt_llm_evals.check_and_create_baseline(this, input_cols, output_col, baseline_version) }}
        {% endif %}
        {{ dbt_llm_evals.capture_io_data_simple(this, input_cols, output_col, sampling_rate, prompt_text) }}
        
    {% endif %}
{% endif %}

{% endmacro %}


{% macro capture_io_data(model_relation, input_columns, output_column, sampling_rate, prompt_text=none) %}

    {% set eval_schema = dbt_llm_evals.get_package_schema() %}
    {% if target.type == 'bigquery' %}
        {% set raw_captures_table = '`' ~ target.database ~ '.' ~ eval_schema ~ '.raw_captures`' %}
        {% set raw_baselines_table = '`' ~ target.database ~ '.' ~ eval_schema ~ '.raw_baselines`' %}
    {% elif target.type == 'databricks' %}
        {% set raw_captures_table = target.database ~ '.' ~ eval_schema ~ '.raw_captures' %}
        {% set raw_baselines_table = target.database ~ '.' ~ eval_schema ~ '.raw_baselines' %}
    {% else %}
        {% set raw_captures_table = eval_schema ~ '.raw_captures' %}
        {% set raw_baselines_table = eval_schema ~ '.raw_baselines' %}
    {% endif %}
    {% set baseline_version = var('llm_evals_baseline_version', 'v1.0') %}
    
    {# Check if baseline exists first, create if needed #}
    {% set baseline_check_query %}
        SELECT COUNT(*) as baseline_count
        FROM {{ raw_baselines_table }}
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
    
    {% set capture_sql %}
    INSERT INTO {{ raw_captures_table }}
    SELECT
        {{ dbt_utils.generate_surrogate_key(["'" ~ model_relation ~ "'", output_column, "'" ~ invocation_id ~ "'", "cast(row_number() over (order by 1) as string)"]) }} as capture_id,
        '{{ model_relation }}' as source_model,
        
        {# Capture inputs as JSON/struct based on warehouse #}
        {% if target.type == 'snowflake' %}
        object_construct(
            {% for col in input_columns %}
            '{{ col }}', {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        ) as input_data,
        {% elif target.type == 'bigquery' %}
        TO_JSON_STRING(STRUCT(
            {% for col in input_columns %}
            {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        )) as input_data,
        {% elif target.type == 'databricks' %}
        named_struct(
            {% for col in input_columns %}
            '{{ col }}', {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        ) as input_data,
        {% else %}
        {# Fallback to JSON string #}
        to_json(
            object(
                {% for col in input_columns %}
                '{{ col }}', {{ col }}{{ ',' if not loop.last }}
                {% endfor %}
            )
        ) as input_data,
        {% endif %}
        
        {{ output_column }} as output_data,
        
        {% if prompt_text %}
        '{{ prompt_text | replace("'", "''") | replace("\n", " ") | replace("\r", " ") }}' as prompt_data,
        {% else %}
        null as prompt_data,
        {% endif %}
        
        {{ dbt_llm_evals.llm_evals__current_timestamp() }} as captured_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'pending' as eval_status,
        cast(null as timestamp) as evaluated_at
        
    FROM {{ model_relation }}
    WHERE {{ output_column }} is not null
        {% if sampling_rate < 1.0 %}
        {% if target.type == 'snowflake' %}
        AND RANDOM() <= {{ sampling_rate }}
        {% else %}
        AND RAND() <= {{ sampling_rate }}
        {% endif %}
        {% endif %}
    {% endset %}
    
    {% do run_query(capture_sql) %}
    
    {% set log_msg = "✓ Captured " ~ input_columns|length ~ " inputs and outputs for evaluation" %}
    {% if sampling_rate < 1.0 %}
        {% set log_msg = log_msg ~ " (sampling: " ~ (sampling_rate * 100)|round(1) ~ "%)" %}
    {% endif %}
    {{ log(log_msg, info=true) }}

{% endmacro %}


{% macro create_baseline_snapshot(model_relation, input_columns, output_column, baseline_version) %}

    {% set eval_schema = dbt_llm_evals.get_package_schema() %}
    {% if target.type == 'bigquery' %}
        {% set baselines_table = '`' ~ target.database ~ '.' ~ eval_schema ~ '.raw_baselines`' %}
    {% elif target.type == 'databricks' %}
        {% set baselines_table = target.database ~ '.' ~ eval_schema ~ '.raw_baselines' %}
    {% else %}
        {% set baselines_table = eval_schema ~ '.raw_baselines' %}
    {% endif %}
    {% set sample_size = var('llm_evals_baseline_sample_size', 100) %}
    
    {# First, mark existing baselines as inactive #}
    {% set deactivate_sql %}
    UPDATE {{ baselines_table }}
    SET is_active = false
    WHERE source_model = '{{ model_relation }}'
        AND is_active = true
    {% endset %}
    
    {% do run_query(deactivate_sql) %}
    
    {# Create new baseline #}
    {% set baseline_sql %}
    INSERT INTO {{ baselines_table }}
    SELECT
        {{ dbt_utils.generate_surrogate_key([output_column, "row_number() over (order by 1)"]) }} as baseline_id,
        '{{ model_relation }}' as source_model,
        '{{ baseline_version }}' as baseline_version,
        
        {# Capture inputs as JSON/struct #}
        {% if target.type == 'snowflake' %}
        object_construct(
            {% for col in input_columns %}
            '{{ col }}', {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        ) as baseline_input,
        {% elif target.type == 'bigquery' %}
        TO_JSON_STRING(STRUCT(
            {% for col in input_columns %}
            {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        )) as baseline_input,
        {% elif target.type == 'databricks' %}
        named_struct(
            {% for col in input_columns %}
            '{{ col }}', {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        ) as baseline_input,
        {% endif %}
        
        {{ output_column }} as baseline_output,
        {{ dbt_llm_evals.llm_evals__current_timestamp() }} as baseline_created_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        true as is_active
        
    FROM {{ model_relation }}
    WHERE {{ output_column }} is not null
    LIMIT {{ sample_size }}
    {% endset %}
    
    {% do run_query(baseline_sql) %}
    
    {{ log("✓ Created baseline version '" ~ baseline_version ~ "' with " ~ sample_size ~ " samples for " ~ model_relation, info=true) }}

{% endmacro %}


{% macro capture_io_data_simple(model_relation, input_columns, output_column, sampling_rate, prompt_text=none) %}

    {% set eval_schema = dbt_llm_evals.get_package_schema() %}
    {% if target.type == 'bigquery' %}
        {% set raw_captures_table = '`' ~ target.database ~ '.' ~ eval_schema ~ '.raw_captures`' %}
    {% elif target.type == 'databricks' %}
        {% set raw_captures_table = target.database ~ '.' ~ eval_schema ~ '.raw_captures' %}
    {% else %}
        {% set raw_captures_table = eval_schema ~ '.raw_captures' %}
    {% endif %}
    
    {% set capture_sql %}
    INSERT INTO {{ raw_captures_table }}
    SELECT
        {{ dbt_utils.generate_surrogate_key(["'" ~ model_relation ~ "'", output_column, "'" ~ invocation_id ~ "'", "cast(row_number() over (order by 1) as string)"]) }} as capture_id,
        '{{ model_relation }}' as source_model,
        
        {# Capture inputs as JSON/struct based on warehouse #}
        {% if target.type == 'snowflake' %}
        object_construct(
            {% for col in input_columns %}
            '{{ col }}', {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        ) as input_data,
        {% elif target.type == 'bigquery' %}
        TO_JSON_STRING(STRUCT(
            {% for col in input_columns %}
            {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        )) as input_data,
        {% elif target.type == 'databricks' %}
        named_struct(
            {% for col in input_columns %}
            '{{ col }}', {{ col }}{{ ',' if not loop.last }}
            {% endfor %}
        ) as input_data,
        {% else %}
        {# Fallback to JSON string #}
        to_json(
            object(
                {% for col in input_columns %}
                '{{ col }}', {{ col }}{{ ',' if not loop.last }}
                {% endfor %}
            )
        ) as input_data,
        {% endif %}
        
        {{ output_column }} as output_data,
        
        {% if prompt_text %}
        '{{ prompt_text | replace("'", "''") | replace("\n", " ") | replace("\r", " ") }}' as prompt_data,
        {% else %}
        null as prompt_data,
        {% endif %}
        
        {{ dbt_llm_evals.llm_evals__current_timestamp() }} as captured_at,
        '{{ invocation_id }}' as dbt_invocation_id,
        'pending' as eval_status,
        cast(null as timestamp) as evaluated_at
        
    FROM {{ model_relation }}
    WHERE {{ output_column }} is not null
        {% if sampling_rate < 1.0 %}
        {% if target.type == 'snowflake' %}
        AND RANDOM() <= {{ sampling_rate }}
        {% else %}
        AND RAND() <= {{ sampling_rate }}
        {% endif %}
        {% endif %}
    {% endset %}
    
    {% do run_query(capture_sql) %}
    
    {% set log_msg = "✓ Captured " ~ input_columns|length ~ " inputs and outputs for evaluation" %}
    {% if sampling_rate < 1.0 %}
        {% set log_msg = log_msg ~ " (sampling: " ~ (sampling_rate * 100)|round(1) ~ "%)" %}
    {% endif %}
    {{ log(log_msg, info=true) }}

{% endmacro %}
