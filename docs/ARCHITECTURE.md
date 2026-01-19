# Architecture & Workflow

This document visualizes how `dbt_llm_evals` integrates with your dbt project and processes evaluations.

```mermaid
graph TD
    %% Styling
    classDef user fill:#f9f,stroke:#333,stroke-width:2px;
    classDef storage fill:#ff9,stroke:#333,stroke-width:2px;
    classDef process fill:#9cf,stroke:#333,stroke-width:2px;
    classDef ai fill:#f96,stroke:#333,stroke-width:4px;

    subgraph "1. User Configuration"
        A[Install Package]:::user --> B[Configure dbt_project.yml]:::user
        B --> C[Add Meta Config & Post-Hook]:::user
    end

    subgraph "2. Execution & Capture"
        D[dbt run User Model]:::process -->|Generates Content| E[Model Output + Prompt]
        E -->|Post-Hook Trigger| F[capture_and_evaluate]:::process
        F -->|Insert Inputs/Outputs/Prompt| G[raw_captures]:::storage
    end

    subgraph "3. Evaluation Engine"
        G -->|Read Pending| H[llm_evals__judge_evaluations]:::process
        I[raw_baselines]:::storage -.->|Compare w/| H
        H -->|Build Prompt| J[Judge Prompt]
        J -->|Call| K{Warehouse AI Interface}:::ai
        K -->|Return JSON| L[Raw Response]
        L -->|Parse & Score| M[llm_evals__judge_evaluations]:::storage
    end

    subgraph "4. Monitoring & Insights"
        M --> N[llm_evals__performance_summary]:::process
        M --> O[llm_evals__drift_detection]:::process
        M --> P[llm_evals__alerts]:::process
        G -.-> Q[llm_evals__capture_status]:::process
        M -.-> Q
    end

    %% Dependencies
    C -.-> D
    K -.->|Snowflake Cortex / Vertex AI / Databricks AI| K
```

## Workflow Description

1.  **User Configuration**: The user sets up the package and adds the necessary metadata and post-hooks to their dbt models.
2.  **Execution & Capture**: When the user's model runs, the post-hook automatically captures the input data, generated output, and prompt template (as configured in YAML meta), storing it in the `raw_captures` table.
3.  **Evaluation Engine**: The `llm_evals__judge_evaluations` model picks up any pending captures. It constructs a comprehensive judge prompt including the original prompt template, inputs, outputs, and baseline examples for comparison. This context-rich evaluation prompt is sent to the warehouse-native AI function and the returned JSON score and reasoning are parsed.
4.  **Monitoring & Insights**: Downstream models aggregate these scores to provide daily performance summaries, drift detection alerts, and overall status tracking.

## Prompt Capture Flow

The package captures prompts through the YAML meta configuration:

```yaml
# models/ai_examples/_your_model.yml
version: 2

models:
  - name: your_model
    config:
      post_hook: "{{ dbt_llm_evals.capture_and_evaluate() }}"
      meta:
        llm_evals:
          enabled: true
          input_columns:
            - customer_question
            - context
          output_column: 'ai_response' 
          prompt: >-
            You are a helpful assistant. Answer the customer's question based on context.
            Context: {context}
            Question: {customer_question}
            Answer:
```

**Capture Process:**
1. The `capture_and_evaluate()` post-hook reads the prompt template from meta configuration
2. Input data is extracted from the specified `input_columns`
3. Output data is extracted from the specified `output_column`
4. All three components (prompt template, inputs, outputs) are stored in `raw_captures`

**Judge Evaluation Context:**
When evaluating, the judge receives full context:
```
=== ORIGINAL PROMPT ===
[The prompt template from YAML config]

=== INPUT ===
[The actual input data]

=== OUTPUT ===
[The AI-generated output]

=== BASELINE EXAMPLES (for reference) ===
[Previous baseline examples from raw_baselines for consistency]
```

This comprehensive context allows the judge to evaluate not just the output quality, but how well the AI followed the original prompt instructions.
