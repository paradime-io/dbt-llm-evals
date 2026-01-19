# dbt™ LLM Evals - Complete Package

## 📦 What's Included

This is a complete, production-ready dbt™ package for evaluating LLM outputs directly within your data warehouse.

### Package Contents

```
📄 Documentation (8 files)
   ├── README.md - Comprehensive documentation
   ├── QUICKSTART.md - 5-minute setup guide
   ├── ARCHITECTURE.md - Architecture and workflow diagrams
   ├── PACKAGE_OVERVIEW.md - This overview document
   ├── STRUCTURE.md - Directory structure explanation
   ├── CHANGELOG.md - Version history
   ├── CONTRIBUTING.md - Contribution guidelines
   └── LICENSE - MIT License

🔧 Configuration (4 files)
   ├── dbt_project.yml - Main configuration
   ├── packages.yml - Dependencies
   ├── pyproject.toml - Python testing dependencies
   └── (setup.sh removed - use dbt run --select llm_evals__setup)

📊 Core Models (5 files)
   ├── llm_evals__setup.sql - One-time setup
   ├── llm_evals__captures.sql - Processed captures (from raw_captures)
   ├── llm_evals__baselines.sql - Processed baselines (from raw_baselines)
   ├── llm_evals__registry.sql - Model registry
   └── _llm_evals__models.yml - Documentation

⚖️ Evaluation Models (3 files)
   ├── llm_evals__judge_evaluations.sql - Main evaluation engine
   ├── llm_evals__eval_scores.sql - Flattened scores
   └── _llm_evals__models.yml - Documentation

📈 Monitoring Models (5 files)
   ├── llm_evals__performance_summary.sql - Performance metrics
   ├── llm_evals__drift_detection.sql - Drift detection
   ├── llm_evals__alerts.sql - Consolidated alerts
   ├── llm_evals__capture_status.sql - Capture status
   └── _llm_evals__models.yml - Documentation

🔌 Adapter Macros (6 files)
   ├── dispatch.sql - Adapter dispatch
   ├── snowflake/ai_functions.sql - Snowflake Cortex
   ├── bigquery/ai_functions.sql - BigQuery Vertex AI
   ├── databricks/ai_functions.sql - Databricks AI
   ├── capture_io.sql - Core capture logic (captures to raw tables)
   └── baseline_check.sql - Baseline management

🎯 Judge Logic (1 file)
   └── build_judge_prompt.sql - Customizable prompts

📝 Examples (3 example projects)
   ├── example_project_snowflake/ - Complete Snowflake example
   ├── example_project_bigquery/ - Complete BigQuery example
   └── example_project_databricks/ - Complete Databricks example

🧪 Testing (3 files)
   ├── test_project_structure.py - Project validation tests
   ├── test_sql_compilation.py - SQL compilation tests
   └── test_example_projects.py - Example project tests
```

## 🚀 Quick Start

### 1. Installation

Add to your `packages.yml`:

```yaml
packages:
  - git: "https://github.com/paradime-io/dbt-llm-evals.git"
    revision: 1.0.0
```

### 2. Run Setup

```bash
dbt run --select llm_evals__setup
```

### 3. Configure Your Model

```yaml
# models/ai_examples/_your_model.yml
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
            - customer_question
            - context
          output_column: 'ai_response'
          prompt: >-
            You are a helpful assistant. Answer the customer's question.
            Context: {context}
            Question: {customer_question}
            Answer:
          sampling_rate: 0.1  # Optional: 10% sampling
```

### 4. Run Your Model

```bash
# First run: Automatically creates baseline + captures data
dbt run --select your_ai_model

# Run evaluation models to evaluate captured data
dbt run --select tag:llm_evals
```

### 5. View Results

```sql
SELECT * FROM llm_evals.llm_evals__performance_summary;
SELECT * FROM llm_evals.llm_evals__alerts WHERE severity = 'ALERT';
```

## 🎯 Key Features

- ✅ **Warehouse-Native**: Uses Snowflake Cortex, BigQuery Vertex AI, or Databricks AI Functions
- ✅ **Zero External Dependencies**: All evaluations run inside your warehouse
- ✅ **Automatic Capture**: Transparent post-hook integration with your AI models
- ✅ **Prompt Capture & Evaluation**: Captures prompts alongside inputs/outputs for comprehensive evaluation
- ✅ **Automatic Baseline Detection**: No manual toggling - baselines created automatically
- ✅ **Baseline Versioning**: Track multiple baseline versions (v1.0, v2.0, etc.)
- ✅ **Multiple Criteria**: Evaluate accuracy, relevance, tone, completeness, and more
- ✅ **Configurable**: Flexible sampling, thresholds, and judge models

## 📚 Documentation

- **QUICKSTART.md** - Get started in 5 minutes
- **README.md** - Full documentation with examples  
- **ARCHITECTURE.md** - Architecture diagrams and workflow
- **STRUCTURE.md** - Understanding the package structure
- **examples/** - Complete working example projects

## 🔧 Supported Warehouses

| Warehouse | AI Service | Status |
|-----------|------------|--------|
| Snowflake | Cortex | ✅ Fully Supported |
| BigQuery | Vertex AI | ✅ Fully Supported |
| Databricks | AI Functions | ✅ Fully Supported |

## 📊 What Gets Evaluated

The package supports evaluating on multiple criteria:

- **Accuracy**: Factual correctness
- **Relevance**: Addresses the input appropriately
- **Tone**: Maintains appropriate tone
- **Completeness**: Fully addresses all aspects
- **Consistency**: Consistent with baseline
- **Helpfulness**: Actionable and useful
- **Clarity**: Clear and well-structured

## 🔍 Monitoring & Alerts

The package automatically monitors:

- Performance trends over time
- Statistical drift detection
- Low pass rates
- Judge confidence issues
- Parse errors

Alerts are generated for:
- Significant score drops
- Pass rate below threshold
- High standard deviation drift
- Consistent parse failures

## 💡 Example Use Cases

1. **Customer Support Responses**
   - Evaluate tone, helpfulness, accuracy
   - Monitor response quality over time
   - Alert on declining performance

2. **Product Descriptions**
   - Ensure consistency and completeness
   - Track against baseline examples
   - A/B test different prompts

3. **Content Generation**
   - Evaluate tone and clarity
   - Monitor for drift
   - Quality assurance at scale

## 🛠️ Configuration Options

### Global Variables

```yaml
vars:
  llm_evals_schema: 'llm_evals'
  llm_evals_judge_model: 'llama3-70b'
  llm_evals_criteria: '["accuracy", "relevance", "tone"]'
  llm_evals_sampling_rate: 0.1  # 10%
  llm_evals_pass_threshold: 7
  llm_evals_drift_stddev_threshold: 2
```

### Model-Level Configuration

```yaml
+meta:
  llm_evals:
    enabled: true
    baseline_version: 'v1.0'      # Optional: defaults to 'v1.0'
    force_rebaseline: false       # Optional: force new baseline
    input_columns:
      - col1
      - col2
    output_column: 'ai_output'
    prompt: >-                     # Optional: prompt template for evaluation context
      You are a helpful assistant. Please respond to:
      Input 1: {col1}
      Input 2: {col2}
      Response:
    sampling_rate: 1.0            # Override global
```

## 📈 Performance & Cost

- **Incremental**: Only evaluates new outputs
- **Sampling**: Control evaluation volume with sampling_rate
- **Batch Processing**: Configurable batch sizes
- **Warehouse-Native**: No data egress costs

Example costs (Snowflake):
- 10K evaluations/day @ 10% sampling = ~1K judge calls/day
- Using llama3-70b ≈ $0.0008 per call
- Total: ~$0.80/day or $24/month

## 🤝 Contributing

Contributions welcome! See CONTRIBUTING.md for guidelines.

## 📄 License

Apache 2.0 License - See LICENSE file

## 🆘 Support

- GitHub Issues: Report bugs or request features
- Documentation: Read the full docs in README.md
- Examples: Check examples/ for working code

## 🎓 Learn More

- [dbt Documentation](https://docs.getdbt.com/)
- [Snowflake Cortex](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [BigQuery AI](https://cloud.google.com/bigquery/docs/generative-ai-overview)
- [Databricks AI Functions](https://docs.databricks.com/en/large-language-models/ai-functions.html)

---

**Built with ❤️ by paradime.io for the dbt™ community**

Get started today and ensure your AI outputs are consistently high-quality!
