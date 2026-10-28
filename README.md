# Weather pipeline

Raw tomorrow.io responses land in GCS bronze as JSON. Local Airflow validates the previous UTC hour, writes a silver CSV, and appends the same rows to a BigQuery gold table. Terraform provisions the cloud side. Secrets stay in Secret Manager.

## Branches

`feature/...` branches are cut from `develop` and merged back with `--no-ff`. `develop` merges into `main` once, after evidence is in.

1. `feature/repo-baseline`
2. `feature/terraform-foundation`
3. `feature/data-stores`
4. `feature/iam`
5. `feature/weather-ingest`
6. `feature/local-airflow`
7. `feature/silver-processing`
8. `feature/runbook`
9. `feature/evidence`
