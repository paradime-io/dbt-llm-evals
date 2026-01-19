import os
import yaml
import pytest
from pathlib import Path

def test_dbt_project_yml_valid():
    """Test that dbt_project.yml is valid YAML and contains required fields."""
    project_file = Path("dbt_project.yml")
    assert project_file.exists(), "dbt_project.yml not found"
    
    with open(project_file) as f:
        config = yaml.safe_load(f)
    
    required_fields = ["name", "version", "config-version", "require-dbt-version"]
    for field in required_fields:
        assert field in config, f"Required field '{field}' missing from dbt_project.yml"

def test_required_macros_exist():
    """Test that all required macros exist."""
    required_macros = [
        "macros/judge/build_judge_prompt.sql",
        "macros/adapters/snowflake/ai_functions.sql",
        "macros/adapters/bigquery/ai_functions.sql", 
        "macros/adapters/databricks/ai_functions.sql",
        "macros/adapters/dispatch.sql"
    ]
    
    for macro in required_macros:
        assert Path(macro).exists(), f"Required macro {macro} not found"

def test_package_structure():
    """Test that required directories exist."""
    required_dirs = [
        "models",
        "macros", 
        "examples"
    ]
    
    for directory in required_dirs:
        assert Path(directory).exists(), f"Required directory {directory} not found"
        assert Path(directory).is_dir(), f"{directory} exists but is not a directory"

def test_package_yml_valid():
    """Test that packages.yml is valid."""
    packages_file = Path("packages.yml")
    assert packages_file.exists(), "packages.yml not found"
    
    with open(packages_file) as f:
        packages_config = yaml.safe_load(f)
    
    assert "packages" in packages_config, "packages.yml missing 'packages' key"