import subprocess
import pytest
import shutil

def test_dbt_compile():
    """Test that all dbt models compile successfully."""
    # Skip if dbt is not available
    if not shutil.which("dbt"):
        pytest.skip("dbt not available in PATH")
    
    result = subprocess.run(
        ["dbt", "compile", "--select", "tag:llm_evals"], 
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"dbt compile failed: {result.stderr}"

def test_dbt_parse():
    """Test that dbt can parse the project successfully."""
    # Skip if dbt is not available
    if not shutil.which("dbt"):
        pytest.skip("dbt not available in PATH")
    
    result = subprocess.run(
        ["dbt", "parse"], 
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"dbt parse failed: {result.stderr}"

def test_dbt_deps():
    """Test that dbt deps runs successfully."""
    # Skip if dbt is not available
    if not shutil.which("dbt"):
        pytest.skip("dbt not available in PATH")
    
    result = subprocess.run(
        ["dbt", "deps"], 
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"dbt deps failed: {result.stderr}"