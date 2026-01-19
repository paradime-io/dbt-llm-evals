# dbt™ LLM Evals Directory Structure

```
dbt_llm_evals/
├── README.md                           # Main documentation
├── QUICKSTART.md                       # Quick start guide
├── ARCHITECTURE.md                     # Architecture diagrams and workflows
├── PACKAGE_OVERVIEW.md                 # Package overview and contents
├── STRUCTURE.md                        # This file - directory structure
├── CHANGELOG.md                        # Version history
├── CONTRIBUTING.md                     # Contribution guidelines
├── LICENSE                             # MIT License
├── .gitignore                          # Git ignore rules
├── dbt_project.yml                     # Main dbt project configuration
├── packages.yml                        # Package dependencies
├── pyproject.toml                      # Python testing dependencies (Poetry)
│
├── macros/                             # Package macros
│   ├── adapters/                       # Warehouse-specific implementations
│   │   ├── dispatch.sql                # Adapter dispatch logic
│   │   ├── snowflake/
│   │   │   └── ai_functions.sql        # Snowflake Cortex functions
│   │   ├── bigquery/
│   │   │   └── ai_functions.sql        # BigQuery Vertex AI functions
│   │   └── databricks/
│   │       └── ai_functions.sql        # Databricks AI functions
│   ├── core/
│   │   ├── capture_io.sql              # Capture and baseline macros
│   │   ├── baseline_check.sql          # Baseline management utilities
│   │   └── get_package_schema.sql      # Schema resolution utilities
│   └── judge/
│       └── build_judge_prompt.sql      # Judge prompt templates
│
├── models/                             # dbt models
│   ├── core/                           # Core data models
│   │   ├── _llm_evals__models.yml      # Schema documentation
│   │   ├── llm_evals__setup.sql        # One-time setup
│   │   ├── llm_evals__captures.sql     # Captured inputs/outputs
│   │   ├── llm_evals__baselines.sql    # Baseline samples
│   │   └── llm_evals__registry.sql     # Model registry
│   │
│   ├── evaluation/                     # Evaluation models
│   │   ├── _llm_evals__models.yml      # Schema documentation
│   │   ├── llm_evals__judge_evaluations.sql  # Main evaluation engine
│   │   └── llm_evals__eval_scores.sql  # Flattened scores
│   │
│   └── monitoring/                     # Monitoring and alerts
│       ├── _llm_evals__models.yml      # Schema documentation
│       ├── llm_evals__performance_summary.sql  # Performance metrics
│       ├── llm_evals__drift_detection.sql      # Drift detection
│       ├── llm_evals__capture_status.sql       # Capture status monitoring
│       └── llm_evals__alerts.sql       # Consolidated alerts
│
├── examples/                           # Example projects
│   ├── example_project_snowflake/      # Complete Snowflake example
│   ├── example_project_bigquery/       # Complete BigQuery example
│   └── example_project_databricks/     # Complete Databricks example
│
├── integration_tests/                  # Integration tests
│   ├── example_config.yml              # Example configuration
│   └── test_snowflake_cortex.sql       # Snowflake integration test
│
└── tests/                              # Python validation tests
    ├── test_project_structure.py       # Project structure validation
    ├── test_sql_compilation.py         # SQL compilation tests
    └── test_example_projects.py        # Example project validation
```

## Key Files

### Configuration
- **dbt_project.yml**: Main configuration with variables and model configs
- **packages.yml**: Dependencies (dbt_utils)
- **pyproject.toml**: Python testing dependencies and Poetry configuration

### Core Macros
- **dispatch.sql**: Cross-warehouse compatibility layer
- **capture_io.sql**: Automatic capture and baseline creation
- **baseline_check.sql**: Baseline version management
- **get_package_schema.sql**: Schema resolution utilities
- **build_judge_prompt.sql**: Customizable judge prompts

### Adapter Implementations
Each warehouse has its own implementation of:
- `llm_evals__ai_complete()`: Call AI model
- `llm_evals__parse_json_response()`: Parse responses
- `llm_evals__current_timestamp()`: Get timestamp

### Core Models
- **llm_evals__setup**: Creates raw storage tables
- **llm_evals__captures**: Incremental capture of AI outputs
- **llm_evals__baselines**: Baseline samples for comparison

### Evaluation Models
- **llm_evals__judge_evaluations**: Runs warehouse AI as judge
- **llm_evals__eval_scores**: Joined view for easy querying

### Monitoring Models
- **llm_evals__performance_summary**: Daily aggregated metrics
- **llm_evals__drift_detection**: Statistical drift detection
- **llm_evals__capture_status**: Capture status monitoring
- **llm_evals__alerts**: Actionable alerts

## Model Dependencies

```
llm_evals__setup (run first)
    ↓ (creates raw_captures and raw_baselines tables)
llm_evals__captures ←─ (populated by post-hook into raw_captures)
llm_evals__baselines ←─ (from raw_baselines)
llm_evals__registry
    ↓
llm_evals__judge_evaluations ←─ (evaluates captures against baselines)
    ↓
llm_evals__eval_scores
    ↓
llm_evals__performance_summary
llm_evals__drift_detection
llm_evals__capture_status
llm_evals__alerts
```

## Tag Organization

- `llm_evals`: All package models
- `core`: Storage and registry models
- `evaluation`: Evaluation engine models
- `monitoring`: Monitoring and alerting models
- `reporting`: User-facing reports
- `alerting`: Alert-generating models
