-- Example Analysis Queries for dbt_llm_evals
-- Save these in your analyses/ folder or run directly

-- ============================================================================
-- PERFORMANCE MONITORING
-- ============================================================================

-- 1. Overall Performance Summary (Last 7 Days)
SELECT
    source_model,
    criterion,
    avg_score,
    pass_rate,
    total_evaluations,
    health_status
FROM llm_evals.llm_evals__performance_summary
WHERE eval_date >= CURRENT_DATE - 7
ORDER BY eval_date DESC, source_model, criterion;

-- 2. Identify Low-Performing Models
SELECT
    source_model,
    criterion,
    avg_score,
    pass_rate,
    fail_count,
    eval_date
FROM llm_evals.llm_evals__performance_summary
WHERE pass_rate < 70
ORDER BY pass_rate ASC, eval_date DESC;

-- 3. Score Trends Over Time
SELECT
    eval_date,
    source_model,
    criterion,
    avg_score,
    pass_rate
FROM llm_evals.llm_evals__performance_summary
WHERE source_model = 'your_model_name'
    AND criterion = 'accuracy'
ORDER BY eval_date DESC
LIMIT 30;

-- ============================================================================
-- DRIFT DETECTION & ALERTS
-- ============================================================================

-- 4. Critical Alerts Requiring Action
SELECT
    source_model,
    criterion,
    alert_type,
    severity,
    message,
    recommended_action
FROM llm_evals.llm_evals__alerts
WHERE severity = 'ALERT'
ORDER BY priority, alert_timestamp DESC;

-- 5. Models with Significant Drift
SELECT
    source_model,
    criterion,
    baseline_avg_score,
    recent_avg_score,
    score_drift,
    pct_change,
    drift_status,
    drift_message
FROM llm_evals.llm_evals__drift_detection
WHERE drift_status IN ('ALERT', 'WARNING')
ORDER BY abs(score_drift) DESC;

-- ============================================================================
-- DETAILED FAILURE ANALYSIS
-- ============================================================================

-- 6. Review Failed Evaluations
SELECT
    source_model,
    criterion,
    score,
    reasoning,
    input_data,
    output_data,
    evaluated_at
FROM llm_evals.llm_evals__eval_scores
WHERE eval_result = 'fail'
    AND evaluated_at >= CURRENT_DATE - 7
ORDER BY score ASC
LIMIT 20;

-- 7. Parse Errors Requiring Review
SELECT
    source_model,
    criterion,
    judge_prompt,
    judge_response,
    evaluated_at
FROM llm_evals.llm_evals__judge_evaluations
WHERE needs_review = true
    AND eval_result = 'parse_error'
ORDER BY evaluated_at DESC
LIMIT 10;

-- 8. Low Confidence Evaluations
SELECT
    source_model,
    criterion,
    score,
    confidence,
    reasoning,
    output_data
FROM llm_evals.llm_evals__eval_scores
WHERE confidence < 0.5
    AND evaluated_at >= CURRENT_DATE - 7
ORDER BY confidence ASC;

-- ============================================================================
-- BASELINE MANAGEMENT
-- ============================================================================

-- 9. Check Baseline Status
SELECT
    source_model,
    baseline_sample_count,
    first_baseline_date,
    latest_baseline_date,
    has_active_baseline,
    status
FROM llm_evals.llm_evals__registry
ORDER BY source_model;

-- 10. Review Baseline Samples
SELECT
    source_model,
    baseline_input,
    baseline_output,
    baseline_created_at,
    is_active
FROM llm_evals.llm_evals__baselines
WHERE source_model = 'your_model_name'
    AND is_active = true
ORDER BY baseline_created_at DESC;

-- ============================================================================
-- COMPARATIVE ANALYSIS
-- ============================================================================

-- 11. Compare Multiple Models
SELECT
    source_model,
    criterion,
    avg(score) as avg_score,
    avg(confidence) as avg_confidence,
    count(*) as eval_count
FROM llm_evals.llm_evals__eval_scores
WHERE evaluated_at >= CURRENT_DATE - 7
GROUP BY source_model, criterion
ORDER BY criterion, avg_score DESC;

-- 12. Score Distribution by Criterion
SELECT
    criterion,
    source_model,
    COUNT(CASE WHEN score >= 8 THEN 1 END) as excellent_count,
    COUNT(CASE WHEN score >= 6 AND score < 8 THEN 1 END) as good_count,
    COUNT(CASE WHEN score >= 4 AND score < 6 THEN 1 END) as fair_count,
    COUNT(CASE WHEN score < 4 THEN 1 END) as poor_count
FROM llm_evals.llm_evals__eval_scores
WHERE evaluated_at >= CURRENT_DATE - 7
GROUP BY criterion, source_model
ORDER BY criterion, source_model;

-- ============================================================================
-- OPERATIONAL METRICS
-- ============================================================================

-- 13. Evaluation Coverage
SELECT
    source_model,
    total_captures,
    evaluated_count,
    pending_count,
    ROUND(100.0 * evaluated_count / NULLIF(total_captures, 0), 2) as coverage_pct
FROM llm_evals.llm_evals__registry
ORDER BY coverage_pct DESC;

-- 14. Daily Evaluation Volume
SELECT
    DATE(evaluated_at) as eval_date,
    source_model,
    COUNT(*) as evaluations_run,
    COUNT(DISTINCT capture_id) as unique_outputs_evaluated
FROM llm_evals.llm_evals__eval_scores
WHERE evaluated_at >= CURRENT_DATE - 30
GROUP BY DATE(evaluated_at), source_model
ORDER BY eval_date DESC, source_model;

-- ============================================================================
-- EXPORT FOR DASHBOARDS
-- ============================================================================

-- 15. Dashboard Summary (Latest Status)
SELECT
    p.source_model,
    p.criterion,
    p.avg_score,
    p.pass_rate,
    p.health_status,
    d.drift_status,
    d.score_drift,
    CASE 
        WHEN a.alert_id IS NOT NULL THEN true 
        ELSE false 
    END as has_alert
FROM llm_evals.llm_evals__performance_summary p
LEFT JOIN llm_evals.llm_evals__drift_detection d
    ON p.source_model = d.source_model
    AND p.criterion = d.criterion
LEFT JOIN llm_evals.llm_evals__alerts a
    ON p.source_model = a.source_model
    AND p.criterion = a.criterion
WHERE p.eval_date = CURRENT_DATE - 1  -- Yesterday's data
ORDER BY p.source_model, p.criterion;
