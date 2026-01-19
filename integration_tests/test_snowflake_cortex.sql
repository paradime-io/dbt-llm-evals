-- Integration test for Snowflake Cortex
-- This file demonstrates how to test the package with Snowflake

-- Test 1: Create a sample AI model with evaluations enabled
{{ config(
    materialized='table',
    tags=['test', 'snowflake']
) }}

with sample_products as (
    select
        1 as product_id,
        'Wireless Headphones' as product_name,
        'Electronics' as category,
        'Noise cancellation, 30hr battery' as features
    union all
    select
        2,
        'Running Shoes',
        'Sports',
        'Lightweight, breathable mesh'
    union all
    select
        3,
        'Coffee Maker',
        'Kitchen',
        'Programmable, 12-cup capacity'
)

select
    product_id,
    product_name,
    category,
    features,
    
    -- Create prompt
    concat(
        'Write a compelling product description for: ',
        product_name,
        '. Category: ', category,
        '. Key features: ', features,
        '. Make it engaging and informative.'
    ) as prompt,
    
    -- Call Snowflake Cortex
    snowflake.cortex.complete(
        'llama3-70b',
        concat(
            'Write a compelling product description for: ',
            product_name,
            '. Category: ', category,
            '. Key features: ', features,
            '. Make it engaging and informative.'
        )
    ) as ai_description,
    
    current_timestamp() as generated_at
    
from sample_products
