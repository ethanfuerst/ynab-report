# Migration from Poetry to uv

This guide will help you migrate your YNAB report project from Poetry to uv, a fast Python package installer and resolver.

## Current State Analysis

Your project currently uses:
- Poetry for dependency management
- `pyproject.toml` with Poetry configuration
- `poetry.lock` file with locked dependencies
- Poetry commands in `deploy_modal.sh`
- Poetry integration in `app.py` for Modal deployment

## Migration Steps

### 1. Install uv

First, install uv if you haven't already:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# or
pip install uv
```

### 2. Update pyproject.toml

Replace the Poetry-specific sections in your `pyproject.toml` with uv-compatible configuration:

**Remove these Poetry-specific sections:**
```toml
[tool.poetry]
[tool.poetry.dependencies]
[tool.poetry.group.dev.dependencies]
[build-system]
```

**Replace with:**
```toml
[project]
name = "ynab-report"
version = "0.1.0"
description = ""
authors = [
    {name = "Ethan Fuerst", email = "34084535+ethanfuerst@users.noreply.github.com"}
]
readme = "README.md"
requires-python = ">=3.10"
dependencies = [
    "certifi>=2024.12.14",
    "urllib3>=2.3.0",
    "pandas>=2.2.3",
    "modal>=1.0.0",
    "duckdb>=1.1.3",
    "sqlfluff>=3.3.0",
    "gspread>=6.1.4",
    "gspread-formatting>=1.2.0",
    "emoji>=2.14.1",
    "sqlmesh[web]>=0.186.1"
]

[project.optional-dependencies]
dev = [
    "ipykernel>=6.29.5"
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

# Keep your existing tool configurations
[tool.black]
line-length = 88
target-version = ["py310"]
skip-string-normalization = true

[tool.isort]
profile = "black"
line_length = 88
multi_line_output = 3
include_trailing_comma = true
force_grid_wrap = 0
use_parentheses = true
ensure_newline_before_comments = true
```

### 3. Handle poetry-dotenv-plugin

The `poetry-dotenv-plugin` dependency needs special attention since it's Poetry-specific. You have a few options:

**Option A: Use python-dotenv directly**
Add to dependencies:
```toml
"python-dotenv>=1.0.0"
```

Then manually load environment variables in your code:
```python
from dotenv import load_dotenv
load_dotenv()
```

**Option B: Use uv's built-in environment handling**
uv has built-in support for `.env` files when using `uv run`.

### 4. Create uv.lock file

Generate the lock file from your current dependencies:

```bash
# Remove the old poetry.lock
rm poetry.lock

# Initialize uv lock file
uv sync
```

### 5. Update deploy_modal.sh

Replace Poetry commands with uv equivalents in `deploy_modal.sh`:

**Replace:**
```bash
if ! command -v poetry &> /dev/null; then
    log "Poetry is not installed. Please install it first." >&2
    exit 1
fi

# Install dependencies using Poetry
poetry install

# Check if modal is available
poetry run modal --version

# Deploy using Poetry
poetry run modal deploy "$FILE"
```

**With:**
```bash
if ! command -v uv &> /dev/null; then
    log "uv is not installed. Please install it first." >&2
    exit 1
fi

# Install dependencies using uv
uv sync

# Check if modal is available
uv run modal --version

# Deploy using uv
uv run modal deploy "$FILE"
```

### 6. Update app.py Modal Configuration

In `app.py`, replace the Poetry-specific Modal configuration:

**Replace:**
```python
.poetry_install_from_file(poetry_pyproject_toml='pyproject.toml')
```

**With:**
```python
.pip_install_from_pyproject("pyproject.toml")
```

### 7. Update Development Workflow

Replace Poetry commands with uv equivalents:

| Poetry Command | uv Equivalent |
|----------------|---------------|
| `poetry install` | `uv sync` |
| `poetry add package` | `uv add package` |
| `poetry add --group dev package` | `uv add --dev package` |
| `poetry remove package` | `uv remove package` |
| `poetry run command` | `uv run command` |
| `poetry shell` | Use `uv run` or activate virtual environment manually |
| `poetry show` | `uv tree` |
| `poetry lock` | `uv lock` |

### 8. Clean Up

Remove Poetry-specific files:
```bash
# Remove Poetry configuration (after backing up if needed)
rm poetry.lock

# Remove Poetry virtual environment if it exists
rm -rf .venv  # if you want to recreate with uv
```

### 9. Initialize uv Environment

```bash
# Create and sync environment
uv sync

# Or if you want to include dev dependencies
uv sync --all-extras
```

### 10. Verify Migration

Test that everything works:

```bash
# Test installation
uv sync

# Test running your application
uv run python app.py

# Test deployment script
./deploy_modal.sh
```

## Benefits of uv over Poetry

- **Speed**: uv is significantly faster than Poetry for dependency resolution and installation
- **Simplicity**: Fewer configuration options, more standardized approach
- **Compatibility**: Better compatibility with standard Python packaging tools
- **Performance**: Written in Rust, much faster than Poetry's Python implementation

## Potential Issues and Solutions

### 1. Environment Variables
If you were relying on `poetry-dotenv-plugin`, make sure to handle environment variables manually or use uv's built-in support.

### 2. Virtual Environment Location
uv creates virtual environments in a different location than Poetry. Update any scripts that hardcode the path.

### 3. Lock File Differences
The `uv.lock` format is different from `poetry.lock`. Make sure to commit the new lock file.

### 4. CI/CD Updates
Update any CI/CD pipelines that use Poetry commands to use uv equivalents.

## Next Steps

1. **Backup**: Make sure to commit your current state before starting the migration
2. **Test**: Test the migration in a development environment first
3. **Update Documentation**: Update any project documentation that references Poetry
4. **Team Communication**: Let your team know about the change and provide this guide

The migration should be straightforward, and you'll likely notice improved performance with dependency operations.