# Weather pipeline

Raw tomorrow.io responses land in GCS bronze as JSON. Local Airflow validates the previous UTC hour, writes a silver CSV, and appends the same rows to a BigQuery gold table. Terraform provisions the cloud side. Secrets stay in Secret Manager.

## Local Airflow

Postgres data and Airflow logs stay in Docker volumes. The DAGs directory is the only project path mounted from this disk.

```bash
docker compose up -d --build
```

UI: http://localhost:8081, user `airflow`, password `airflow`. Host port 8081 keeps this stack off the other local Airflow on 8080.

The Airflow service account key is not part of the image. After Terraform creates `weather-airflow`, save it as `.secrets/airflow-sa.json`. Compose mounts that directory read-only and sets `GOOGLE_APPLICATION_CREDENTIALS` inside the container. The UI still starts if the file is missing. GCP calls from a DAG need the real key.

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
