# Secret, scheduler, and the silver DAG

Run this after [setup](setup.md). The tomorrow.io key is already in Secret Manager. This page starts local Airflow, writes one bronze file, and loads silver plus gold.

## Airflow identity

`gcloud iam service-accounts keys create` fails here. The project enforces `constraints/iam.disableServiceAccountKeyCreation`, so there is no JSON key to download. Terraform grants your user `roles/iam.serviceAccountTokenCreator` on `weather-airflow`. The DAG and the Google connection impersonate that account. Your login only mints the token.

```bash
mkdir -p .secrets
cp "$HOME/.config/gcloud/application_default_credentials.json" .secrets/adc.json
```

The copy stays out of git. Recreate the local stack so the container picks up the file and `GCP_PROJECT_ID`:

```bash
docker compose up -d
```

UI: http://localhost:8081, user `airflow`, password `airflow`. The DAG name in the UI is `weather silver processing`.

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
