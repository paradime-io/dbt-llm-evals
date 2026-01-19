import yaml
from pathlib import Path

def test_example_projects_valid():
    """Test that example projects have valid dbt_project.yml files."""
    example_dirs = [
        "examples/example_project_snowflake",
        "examples/example_project_bigquery", 
        "examples/example_project_databricks"
    ]
    
    for example_dir in example_dirs:
        project_file = Path(example_dir) / "dbt_project.yml"
        assert project_file.exists(), f"Example {example_dir} missing dbt_project.yml"
        
        with open(project_file) as f:
            config = yaml.safe_load(f)
        
        # Check that the example uses the dbt_llm_evals package
        packages_file = Path(example_dir) / "packages.yml"
        if packages_file.exists():
            with open(packages_file) as f:
                packages_config = yaml.safe_load(f)
            
            package_names = []
            for package in packages_config.get("packages", []):
                if "git" in package:
                    # Extract package name from git URL or path
                    git_url = package["git"]
                    if "dbt-llm-evals" in git_url:
                        package_names.append("dbt_llm_evals")
                elif "local" in package:
                    package_names.append("dbt_llm_evals")
            
            assert "dbt_llm_evals" in package_names, f"Example {example_dir} not using dbt_llm_evals package"

def test_example_profiles_exist():
    """Test that example projects have profiles.yml files."""
    example_dirs = [
        "examples/example_project_snowflake",
        "examples/example_project_bigquery", 
        "examples/example_project_databricks"
    ]
    
    for example_dir in example_dirs:
        profiles_file = Path(example_dir) / "profiles.yml"
        assert profiles_file.exists(), f"Example {example_dir} missing profiles.yml"