# Production deployment and scheduling

GitHub deploys validated `main` commits to Modal through the protected GitHub `production` environment. Railway submits the daily job; Modal owns execution, retries, pipeline secrets, and logs.

## Inventory

| Setting | Existing production behavior | Migration |
| --- | --- | --- |
| App / Modal environment | `fiscal-pipeline` / `main` | Preserved; GitHub environment is separately named `production` |
| Function / arguments | `update_google_sheet()`; S3 sync and dashboard refresh enabled, remote execution, `env='prod'` | Preserved |
| Cadence | `5 8 * * *`, UTC; removed from source in `88a6282` / PR #50 | One Railway service, daily at 08:05 UTC (04:05 EDT / 03:05 EST) |
| Timeout | Modal default: 300 seconds per attempt | Explicit 300 seconds |
| Retries | Three retries, initial delay 60 seconds, coefficient 1.0 | Preserved on Modal; Railway restart policy `NEVER` |
| Concurrency | No explicit container limit; one input per container | One container to serialize pipeline writes; drain old deployment before cutover |
| Secrets | Modal `fiscal-pipeline-secrets` | Preserved; add `FISCAL_COMPLETION_HEALTHCHECK_URL` for completion monitoring |
| Health checks / notifications | No heartbeat or notification integration found in source | Success heartbeat after full production refresh; configure missed-heartbeat and Railway failure alerts |
| Python / image builder | Python 3.10; builder previously unpinned | Python 3.10 preserved; builder `2025.06`, matching box-office-tracking |

Read-only inspection on September 6, 2026 found production app `ap-eLnyoEKE12jfy2cZt7rMOA`, deployed from `88a6282` on August 28, with zero active tasks. Source history contains one cadence. GitHub inspection found no environments and no classic main-branch protection; configure these before merge. Recheck live function settings and any external scheduler/alert configuration before cutover; these are not fully represented by Git history.

## Before merge

- [ ] Create/configure GitHub environment `production`: allow deployments only from `main`, require reviewer approval, and disable protection bypass where available. Confirm the repository plan supports these protections before storing credentials.
- [ ] Add `MODAL_TOKEN_ID` and `MODAL_TOKEN_SECRET` only as GitHub `production` environment secrets; remove any repository/organization-wide copies exposed to PR jobs. Verify access to Modal environment `main` and existing `fiscal-pipeline-secrets` without copying pipeline secrets to GitHub or Railway.
- [ ] Require the `Validate pull request` check on protected `main` and restrict direct pushes. Confirm PR validation passes without Modal credentials.
- [ ] Review the live Modal function inventory against the table; record any external schedules, overrides, alert recipients, and active/queued calls. Confirm no other scheduler submits this job.
- [ ] Create one Railway cron service from this repository using `/railway.toml` and `Dockerfile.trigger`. Set `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, and `RAILWAY_TRIGGERS_ENABLED=false`. Keep it disabled during setup and cutover, including deployment-triggered starts.
- [ ] Configure Railway failed-run notifications and GitHub deployment failure notifications. Create a completion monitor due daily at 08:05 UTC with at least 30 minutes grace for startup, four 300-second attempts, and retry delays; add its success URL as `FISCAL_COMPLETION_HEALTHCHECK_URL` in the Modal pipeline secret. Confirm alert recipients and test the monitor independently.
- [ ] Confirm all existing Modal schedules are removed/disabled and wait for active and queued executions to drain before approving the first production deployment. Freeze manual pipeline runs during cutover.

## After merge

- [ ] Approve the GitHub production deployment. Confirm validation, image build, deployment, and metadata verification succeed for the merged SHA; inspect the workflow summary and Modal history. This PR does not deploy production or build its remote image during local validation.
- [ ] Check the Modal dashboard contains only the expected pipeline and metadata functions and no schedules; confirm timeout, retries, secret, and container limit. Metadata verification checks revision, app, target, environment, builder pin, and empty schedule configuration; credential-free tests also reject schedules in `app.py`.
- [ ] In the Railway container, run `python scripts/railway_trigger.py daily --check-only`; confirm `verified` without a pipeline call. Keep `RAILWAY_TRIGGERS_ENABLED=false` until this passes and old work is drained.
- [ ] Enable the single Railway service by setting `RAILWAY_TRIGGERS_ENABLED=true` away from 08:05 UTC. Treat any start caused by this deployment as the smoke run; do not also manually submit it. Confirm one `submitted` log with its Modal call ID, successful Modal completion, fresh production Sheets data, and a completion heartbeat before the next daily trigger.
- [ ] Observe the next 08:05 UTC invocation and verify exactly one submission and successful completion. Confirm disabled/missing triggers are caught by the completion monitor and failed submissions by Railway notifications.

## Operations and rollback

- Manual remote invocation: `uv run modal run --env main app.py::update_google_sheet`. Local invocation remains `uv run python app.py --sync-s3 --update-dashboards --env dev`. Coordinate manual production runs with Railway; the container limit serializes work but does not deduplicate submissions.
- Railway logs the call ID immediately after `.spawn()` and exits without waiting for compute. A submitted call is not proof of completion. Use Modal logs and the completion monitor for asynchronous failures. If submission times out ambiguously, inspect Modal before retrying; never enable Railway automatic restarts for this trigger. See [Modal function lookups](https://modal.com/docs/guide/trigger-deployed-functions) and [Railway cron jobs](https://docs.railway.com/cron-jobs).
- Heartbeats are sent only after both pipeline stages finish on a remote production run. A heartbeat delivery failure is logged without retrying an already completed financial refresh; the external monitor alerts on missing completion. Pipeline errors still propagate to Modal for its existing retries.
- For rollback, disable Railway first and drain active/queued Modal work. Dispatch `Modal production deployment` from `main` with a full 40-character `revision` SHA reachable from `main`. Choose a revision containing this deployment tooling and no Modal schedules; older revisions are unsupported and fail validation. Approve, inspect metadata/history, run `--check-only`, then re-enable Railway once. Never restore a legacy Modal cron while Railway is enabled.
- Production deployments are serialized and running deployments are not canceled by new pushes. A failed verification fails the workflow but does not undo a deployed revision; keep Railway disabled during recovery and explicitly redeploy a known-good revision. GitHub branch/environment protections and external alert configuration must be maintained outside this repository.
