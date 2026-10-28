# Secret, scheduler, and the silver DAG

Run this after [setup](setup.md). The tomorrow.io key is already in Secret Manager. This page adds the Airflow key, writes one bronze file, and loads silver plus gold.

## Airflow key

The email is the `airflow` value of `service_account_emails`. With the default names it is `weather-airflow@YOUR_PROJECT_ID.iam.gserviceaccount.com`.

```bash
mkdir -p .secrets
gcloud iam service-accounts keys create .secrets/airflow-sa.json \
  --iam-account=weather-airflow@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

The file stays out of git. Recreate the local stack so the container picks up the key and `GCP_PROJECT_ID`:

```bash
docker compose up -d
```

UI: http://localhost:8081, user `airflow`, password `airflow`.

This repository sits on the external disk `Новый том`. Docker Desktop does not share that disk by default, so the container's `dags/` directory stays empty and the DAG never appears. Share the disk in Docker Desktop under Settings, Resources, File sharing, then run `docker compose up -d` again.

## One bronze file

The scheduler name is output `scheduler_job_name`. With the defaults it is `weather-dev-ingest` in `europe-west1`.

```bash
gcloud scheduler jobs run weather-dev-ingest --location=europe-west1
gcloud storage ls "gs://weather-dev-YOUR_PROJECT_ID/bronze/weather/realtime/minsk/**"
```

A successful call writes `bronze/weather/realtime/minsk/YYYY/MM/DD/HH/<timestamp>.json`. Leave the job in place: it keeps writing every 10 minutes. Several of those files, not one manual call, are the proof for the schedule.

## Silver and gold

Without `source_path`, the DAG reads the previous UTC hour. A file written a minute ago is still in the current hour, so the first run needs the prefix you just listed.

In the Airflow UI open `weather_silver_processing` and trigger it with:

```json
{"source_path": "bronze/weather/realtime/minsk/YYYY/MM/DD/HH/"}
```

The graph is `resolve_source_prefix`, then `write_silver_csv`, then `load_gold`. The second task logs how many rows it kept and how many it dropped. No JSON in the prefix fails the run. Zero rows left after validation fails the run too.

The CSV lands at `silver/weather/realtime/minsk/YYYY/MM/DD/HH/<run_ts>.csv`. The same rows are appended to `weather_dev.realtime_gold`.

```sql
SELECT *
FROM `YOUR_PROJECT_ID.weather_dev.realtime_gold`
ORDER BY ingested_at_utc DESC
```

After the UTC hour changes, trigger the DAG once more with an empty `source_path`. That run is the one that proves the default previous-hour path.
