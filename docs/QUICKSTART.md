# Quick Start Guide

Get started with dbt_llm_evals in 5 minutes!

## Step 1: Install the Package

Add to your `packages.yml`:

```yaml
packages:
  - package: paradime-io/dbt_llm_evals
    version: [">=1.0.0", "<2.0.0"]
```

Run:
```bash
dbt deps
```

## Step 2: Run Setup

Create the storage tables:

```bash
dbt run --select llm_evals__setup
```

## Step 3: Configure Global Variables

Configure required variables in your `dbt_project.yml`:

```yaml
vars:
  # Judge model (warehouse-specific)
  llm_evals_judge_model: 'llama3-70b'  # Snowflake
  # llm_evals_judge_model: 'gemini-pro'  # BigQuery
  # llm_evals_judge_model: 'llama-2-70b-chat'  # Databricks
  
  # Evaluation criteria
  llm_evals_criteria: '["accuracy", "relevance", "tone", "completeness"]'
  
  # Optional: customize other settings
  llm_evals_sampling_rate: 0.1  # 10% of outputs
  llm_evals_pass_threshold: 7  # Score >= 7 is pass
```

## Step 4: Configure Your AI Model

Create a model-specific YAML file:

```yaml
# models/ai_examples/_your_ai_model.yml
version: 2

models:
  - name: your_ai_model
    config:
      materialized: table
      post_hook: "{{ dbt_llm_evals.capture_and_evaluate() }}"
      meta:
        llm_evals:
          enabled: true
          baseline_version: 'v1.0'  # Optional: specify version
          input_columns:
            - input_col1
            - input_col2
          output_column: 'ai_output_col'
          prompt: >-
            You are a helpful assistant. Please respond to the following input.
            Input 1: {input_col1}
            Input 2: {input_col2}
            Please provide a helpful and accurate response:
          sampling_rate: 0.1  # Optional: 10% sampling
```

## Step 5: Run Your Model

**That's it!** No manual baseline creation needed. Just run:

```bash
dbt run --select your_ai_model
```

The package **automatically**:
- ✅ **Detects** no baseline exists for v1.0
- ✅ **Creates** baseline with 100 samples 
- ✅ **Captures** inputs, outputs, and prompts for future evaluation
- ✅ **Logs**: `No baseline found for version 'v1.0'. Creating baseline with 100 samples...`

## Step 6: Run Evaluation Models

Process the captured data through the evaluation engine:

```bash
# Run evaluation models to score captured outputs
dbt run --select tag:llm_evals
```

This will:
- ✅ **Evaluate** captured outputs against baseline using AI judge
- ✅ **Calculate** scores for each criterion (accuracy, relevance, tone)
- ✅ **Generate** monitoring alerts and performance summaries

## Step 7: Monitor Results

Check results:
```sql
-- View performance summary
SELECT * FROM llm_evals.llm_evals__performance_summary
ORDER BY eval_date DESC;

-- Check for alerts
SELECT * FROM llm_evals.llm_evals__alerts
WHERE severity = 'ALERT';

-- Review low scores
SELECT 
    input_data,
    output_data,
    criterion,
    score,
    reasoning
FROM llm_evals.llm_evals__eval_scores
WHERE score < 5
ORDER BY score ASC;
```

## Complete Example

Here's a full working example:

```sql
-- models/ai_content/product_descriptions.sql
{{ config(
    materialized='table',
    post_hook="{{ dbt_llm_evals.capture_and_evaluate() }}",
    meta={
        'llm_evals': {
            'enabled': true,
            'input_columns': ['product_name', 'features'],
            'output_column': 'ai_description'
        }
    }
) }}

SELECT
    product_id,
    product_name,
    features,
    
    -- Snowflake Cortex example
    snowflake.cortex.complete(
        'llama3-70b',
        concat('Write a product description for: ', product_name, '. Features: ', features)
    ) as ai_description
    
FROM {{ ref('stg_products') }}
```

```yaml
# dbt_project.yml
vars:
  llm_evals_judge_model: 'llama3-70b'
  llm_evals_criteria: '["accuracy", "relevance", "tone"]'
  llm_evals_sampling_rate: 0.1  # 10% sampling
```

That's it! Your AI outputs are now being evaluated automatically.

## Baseline Versioning (Advanced)

When your AI model changes significantly, create a new baseline version:

```yaml
+meta:
  llm_evals:
    enabled: true
    baseline_version: 'v2.0'  # New version
    input_columns:
      - input_col1
      - input_col2
    output_column: 'ai_output_col'
```

Or force refresh existing version:

```yaml
+meta:
  llm_evals:
    enabled: true
    force_rebaseline: true     # Force new baseline
    baseline_version: 'v2.0'   # Version to refresh
    input_columns:
      - input_col1
      - input_col2
    output_column: 'ai_output_col'
```

Check baseline versions:

```sql
SELECT 
    baseline_version,
    is_active,
    baseline_created_at,
    COUNT(*) as sample_count
FROM llm_evals.raw_baselines
WHERE source_model = 'your_model_name'
GROUP BY baseline_version, is_active, baseline_created_at
ORDER BY baseline_created_at DESC;
```

## Next Steps

- [Read the full README](README.md) for advanced configuration
- [View example projects](examples/) for complete working examples
- [Check warehouse-specific setup](README.md#warehouse-specific-setup)
- [Review architecture diagrams](ARCHITECTURE.md)

## Troubleshooting

**Q: Evaluations not running?**
- Check `enabled: true` in meta config
- Verify post-hook is configured
- Run `dbt run --select llm_evals__setup` first

**Q: Parse errors?**
- Check judge model output format
- Review `llm_evals__judge_evaluations` table
- Verify warehouse-specific parsing logic

**Q: Too expensive?**
- Lower sampling_rate: `0.01` (1%)
- Reduce batch_size
- Use smaller judge models

Need help? Open an issue on GitHub!
