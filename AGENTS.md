# fiscal-pipeline — project notes

Personal finance pipeline: pulls YNAB budget data, lands it in S3, builds a DuckDB warehouse via sqlmesh, and refreshes Google Sheets dashboards. Runs on Modal.

## Stack
- Python 3.12 (`.python-version`), `uv` for deps, `hatchling` build backend.
- Runtime: `modal`, `eftoolkit`, `sqlmesh[web]`, `pandas`, `python-dotenv`, `requests`.
- Dev tools live in `[dependency-groups].dev`: `pytest`, `ipykernel`, `ruff`, `pre-commit`.
- Lint + format: Ruff only (`ruff-check` + `ruff-format`). No Black, no isort.

## Commands
- Install / sync: `uv sync`
- Tests: `uv run pytest`
- Pre-commit: `uv run pre-commit run --all-files`
- Run locally: `uv run python app.py --sync-s3 --update-dashboards`
- Deploy / run on Modal: `uv run modal deploy app.py`

## Layout
- `app.py` — Modal entrypoint and pipeline wiring.
- `src/etl/` — YNAB and paystub extraction to S3 via `eftoolkit`.
- `src/warehouse/` — DuckDB warehouse build; sqlmesh project at `src/warehouse/sqlmesh_project/`.
- `src/sheets/` — Google Sheets refresh. Current dashboard surface is the overview worksheets backed by `dashboards.monthly_level` and `dashboards.yearly_level`.
- `src/utils/__init__.py` — `get_s3()` and `get_duckdb()` factories that pass DO Spaces creds explicitly. Use these instead of constructing `DuckDB(...)` / `S3FileSystem(...)` directly.
- `dashboards/` — Evidence dashboards.
- `tests/` — pytest tests organized by area.

## Gotchas
- Modal image pins `python_version='3.10'` while local is 3.12; do not change it without checking Modal compatibility.
- Ruff formatter uses `quote-style = "preserve"` so the existing single-quote convention stays.
- Secrets load from `.env` via `python-dotenv`; Modal uses `modal.Secret.from_name('fiscal-pipeline-secrets')`.
- `S3_SECRET_ACCESS_KEY_ID` has a project-specific `_ID` suffix. `get_s3()` / `get_duckdb()` pass creds explicitly so eftoolkit env fallbacks are not used accidentally.
- No CI is configured; pre-commit is the enforcement gate.
