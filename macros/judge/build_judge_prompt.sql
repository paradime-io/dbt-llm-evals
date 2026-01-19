{% macro build_judge_prompt(input_col, output_col, criterion, baseline_examples=none, prompt_data_col=none) %}

{%- set criterion_configs = {
    'accuracy': {
        'title': 'Accuracy',
        'description': 'Evaluate if the output is factually accurate and correct based on the input.',
        'scale': '1-10 where 1=completely inaccurate, 10=perfectly accurate'
    },
    'relevance': {
        'title': 'Relevance',
        'description': 'Evaluate if the output directly addresses and is relevant to the input.',
        'scale': '1-10 where 1=not relevant at all, 10=highly relevant'
    },
    'tone': {
        'title': 'Tone Appropriateness',
        'description': 'Evaluate if the output maintains an appropriate professional tone.',
        'scale': '1-10 where 1=inappropriate tone, 10=perfect tone'
    },
    'completeness': {
        'title': 'Completeness',
        'description': 'Evaluate if the output fully addresses all aspects mentioned in the input.',
        'scale': '1-10 where 1=incomplete, 10=comprehensive'
    },
    'consistency': {
        'title': 'Consistency with Baseline',
        'description': 'Evaluate if the output is consistent in quality and style with the baseline examples.',
        'scale': '1-10 where 1=very inconsistent, 10=perfectly consistent'
    },
    'helpfulness': {
        'title': 'Helpfulness',
        'description': 'Evaluate if the output would be helpful and actionable for the user.',
        'scale': '1-10 where 1=not helpful at all, 10=extremely helpful'
    },
    'clarity': {
        'title': 'Clarity',
        'description': 'Evaluate if the output is clear, well-structured, and easy to understand.',
        'scale': '1-10 where 1=very unclear, 10=perfectly clear'
    }
} -%}

{%- set config = criterion_configs.get(criterion, {
    'title': criterion|title,
    'description': 'Evaluate the quality of the output based on ' ~ criterion,
    'scale': '1-10 where 1=very poor, 10=excellent'
}) -%}

concat(
    'You are an expert evaluator. Your task is to evaluate an AI-generated output.\n\n',
    
    {% if prompt_data_col %}
    '=== ORIGINAL PROMPT ===\n',
    coalesce({{ prompt_data_col }}, 'No prompt captured'), '\n\n',
    {% endif %}
    
    '=== INPUT ===\n',
    {% if target.type == 'bigquery' %}
    coalesce(TO_JSON_STRING({{ input_col }}), 'N/A'), '\n\n',
    {% else %}
    coalesce(cast({{ input_col }} as string), 'N/A'), '\n\n',
    {% endif %}
    
    '=== OUTPUT ===\n',
    coalesce(cast({{ output_col }} as string), 'N/A'), '\n\n',
    
    {% if baseline_examples %}
    '=== BASELINE EXAMPLES (for reference) ===\n',
    coalesce(cast({{ baseline_examples }} as string), 'N/A'), '\n\n',
    {% endif %}
    
    '=== EVALUATION TASK ===\n',
    'Criterion: {{ config.title }}\n',
    'Description: {{ config.description }}\n',
    'Scale: {{ config.scale }}\n\n',
    
    '=== INSTRUCTIONS ===\n',
    '1. Carefully review the input and output above\n',
    '2. Evaluate the output based solely on the criterion: {{ config.title }}\n',
    '3. Provide a score on the specified scale (1-10)\n',
    '4. Explain your reasoning in 2-3 clear sentences\n',
    '5. Indicate your confidence in this evaluation (0.0-1.0)\n\n',
    
    '=== RESPONSE FORMAT ===\n',
    'You MUST respond with ONLY valid JSON in this exact format.\n',
    'Do not include any markdown formatting, code blocks, or additional text.\n\n',
    'Format:\n',
    '{"score": <integer 1-10>, "reasoning": "<your explanation>", "confidence": <decimal 0.0-1.0>}\n\n',
    
    'JSON Response:'
)

{% endmacro %}


{% macro get_eval_criteria() %}
    {%- set criteria_json = var('llm_evals_criteria', '["accuracy", "relevance"]') -%}
    {{ return(fromjson(criteria_json)) }}
{% endmacro %}
