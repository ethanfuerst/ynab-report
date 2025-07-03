# SQLMesh Modal Deployment Issue Analysis

## Problem
When deploying the project with Modal, SQLMesh throws the error:
```
sqlmesh.utils.errors.ConfigError: No models were found
```

Even though the config location `/root/src/warehouse/sqlmesh_project` is correct and contains the `config.py` file.

## Root Cause Analysis

### Directory Structure
The SQLMesh project is located at `src/warehouse/sqlmesh_project/` and contains:
- `config.py` - SQLMesh configuration file
- `models/` directory with SQL files organized in subdirectories:
  - `_1_raw/` - 6 SQL model files
  - `_2_cleaned/` - 7 SQL model files  
  - `_3_combined/` - 4 SQL model files
  - `_4_dashboards/` - 3 SQL model files

### Modal Image Configuration Issue
The Modal image was configured as:
```python
modal_image = (
    modal.Image.debian_slim(python_version='3.10')
    .poetry_install_from_file(poetry_pyproject_toml='pyproject.toml')
    .add_local_dir('src/sheets/assets/formatting_configs/', ...)
    .add_local_dir('src/sheets/assets/column_ordering/', ...)
    .add_local_python_source('src')  # ← This only copies .py files!
)
```

### The Problem
- `add_local_python_source('src')` only copies Python files (`.py`)
- SQLMesh model files are SQL files (`.sql`) 
- While `config.py` gets copied (it's a Python file), the `.sql` model files do not
- SQLMesh finds the config but no models, hence the "No models were found" error

### Path Resolution Verification
The `project_root` calculation works correctly in Modal:
- `project_root = Path(__file__).parent.parent` where `__file__` is `/root/src/__init__.py`
- Results in `project_root = /root`
- SQLMesh context path: `project_root / 'src' / 'warehouse' / 'sqlmesh_project'` = `/root/src/warehouse/sqlmesh_project` ✓

## Solution
Add the SQLMesh project directory explicitly to the Modal image:

```python
modal_image = (
    modal.Image.debian_slim(python_version='3.10')
    .poetry_install_from_file(poetry_pyproject_toml='pyproject.toml')
    .add_local_dir(
        'src/sheets/assets/formatting_configs/',
        remote_path='/app/src/sheets/assets/formatting_configs/',
    )
    .add_local_dir(
        'src/sheets/assets/column_ordering/',
        remote_path='/app/src/sheets/assets/column_ordering/',
    )
    .add_local_dir(
        'src/warehouse/sqlmesh_project/',
        remote_path='/app/src/warehouse/sqlmesh_project/',
    )  # ← Added this line
    .add_local_python_source('src')
)
```

This ensures all SQL model files are copied to the Modal container at the correct path.

## Key Learnings
1. `add_local_python_source()` only copies Python files, not other file types
2. SQLMesh requires both the config AND the model files to be present
3. Always explicitly copy non-Python assets that your application depends on
4. Modal's file copying behavior differs between `add_local_python_source()` and `add_local_dir()`