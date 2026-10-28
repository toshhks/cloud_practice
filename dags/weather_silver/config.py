import os
from dataclasses import dataclass

DAG_ID = "weather_silver_processing"
DAG_DESCRIPTION = "weather silver processing"
GCP_CONN_ID = "google_cloud_default"

COLUMNS = (
    ("source_object", "STRING", "REQUIRED"),
    ("event_time", "TIMESTAMP", "REQUIRED"),
    ("location_name", "STRING", "REQUIRED"),
    ("location_lat", "FLOAT64", "NULLABLE"),
    ("location_lon", "FLOAT64", "NULLABLE"),
    ("location_type", "STRING", "NULLABLE"),
    ("ingested_at_utc", "TIMESTAMP", "REQUIRED"),
    ("weather_temperature", "FLOAT64", "NULLABLE"),
    ("weather_humidity", "FLOAT64", "NULLABLE"),
    ("weather_windSpeed", "FLOAT64", "NULLABLE"),
    ("weather_cloudCover", "FLOAT64", "NULLABLE"),
    ("weather_precipitationProbability", "FLOAT64", "NULLABLE"),
)

CSV_COLUMNS = [name for name, _type, _mode in COLUMNS]
BQ_SCHEMA = [{"name": name, "type": field_type, "mode": mode} for name, field_type, mode in COLUMNS]

WEATHER_FIELDS = {
    "temperature": "weather_temperature",
    "humidity": "weather_humidity",
    "windSpeed": "weather_windSpeed",
    "cloudCover": "weather_cloudCover",
    "precipitationProbability": "weather_precipitationProbability",
}

VALUE_RANGES = {
    "humidity": (0, 100),
    "cloudCover": (0, 100),
    "precipitationProbability": (0, 100),
    "temperature": (-90, 70),
    "windSpeed": (0, 150),
}


@dataclass(frozen=True)
class Settings:
    project_id: str
    bucket: str
    dataset: str
    table: str
    location_slug: str

    @property
    def destination_table(self) -> str:
        return f"{self.project_id}.{self.dataset}.{self.table}"

    @property
    def airflow_principal(self) -> str:
        configured = os.environ.get("WEATHER_AIRFLOW_SA", "").strip()
        return configured or f"weather-airflow@{self.project_id}.iam.gserviceaccount.com"


def load_settings() -> Settings:
    """Read runtime settings. Called from tasks, not while the scheduler parses the DAG."""
    project_id = os.environ.get("GCP_PROJECT_ID", "").strip()
    env_name = os.environ.get("WEATHER_ENV", "dev").strip() or "dev"
    location_slug = os.environ.get("WEATHER_LOCATION_SLUG", "minsk").strip() or "minsk"
    bucket = os.environ.get("WEATHER_BUCKET", "").strip() or (
        f"weather-{env_name}-{project_id}" if project_id else ""
    )
    dataset = os.environ.get("WEATHER_DATASET", "").strip() or f"weather_{env_name}"
    table = os.environ.get("WEATHER_TABLE", "").strip() or "realtime_gold"

    missing = [
        name
        for name, value in (("GCP_PROJECT_ID", project_id), ("WEATHER_BUCKET", bucket))
        if not value
    ]
    if missing:
        raise RuntimeError(
            "Set GCP_PROJECT_ID so the DAG can build the Terraform bucket name, "
            f"or set WEATHER_BUCKET directly. Missing: {', '.join(missing)}"
        )

    return Settings(
        project_id=project_id,
        bucket=bucket,
        dataset=dataset,
        table=table,
        location_slug=location_slug,
    )
