-- Example model showing how to use dbt_llm_evals
-- models/ai_content/customer_support_responses.sql

WITH support_tickets AS (
    select
        ticket_id,
        customer_id,
        customer_name,
        customer_question,
        ticket_category,
        ticket_priority,
        customer_tier,
        
        concat(
            'Customer: ', customer_name,
            ', Tier: ', customer_tier,
            ', Previous interactions: ', previous_interaction_count
        ) as customer_context,
        
        -- Pre-calculate prompt
        concat(
            'You are a helpful customer support agent. ',
            'Respond to this customer question professionally and helpfully.\n\n',
            'Customer Context: ', 
            concat(
                'Customer: ', customer_name,
                ', Tier: ', customer_tier,
                ', Previous interactions: ', previous_interaction_count
            ), '\n',
            'Category: ', ticket_category, '\n',
            'Question: ', customer_question, '\n\n',
            'Response:'
        ) as ai_prompt
        
    from {{ ref('support_tickets_seed') }}
    where status = 'pending_ai_response'
)

select
    ticket_id,
    customer_id,
    customer_name,
    customer_question,
    ticket_category,
    customer_context,
    
    -- Call warehouse AI function (Databricks example)
    -- Uses Databricks ai_query function
    ai_query(
        '{{ var("llm_evals_judge_model") }}',
        ai_prompt
    ) as ai_response,
    
    current_timestamp() as generated_at
    
from support_tickets

-- This model will automatically:
-- 1. Capture inputs (customer_question, customer_context, ticket_category)
-- 2. Capture output (ai_response)
-- 3. Evaluate using configured criteria (accuracy, relevance, tone, etc.)
-- 4. Store scores in llm_evals schema
-- 5. Alert on drift or quality issues
