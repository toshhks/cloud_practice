import csv
import io
import json
import logging
import re
from datetime import datetime, timedelta, timezone

from weather_silver.config import CSV_COLUMNS, VALUE_RANGES, WEATHER_FIELDS, load_settings

LOGGER = logging.getLogger(__name__)
HOUR_IN_PREFIX = re.compile(r"(\d{4})/(\d{2})/(\d{2})/(\d{2})/")


def resolve_source_prefix(**context) -> dict:
    settings = load_settings()
    raw_path = context["params"].get("source_path") or ""
    prefix = _normalize_prefix(str(raw_path), settings.bucket)
    if not prefix:
        prefix = _previous_hour_prefix(settings.location_slug)

    LOGGER.info("Reading bronze prefix gs://%s/%s", settings.bucket, prefix)
    return {
        "bucket": settings.bucket,
        "prefix": prefix,
        "location_slug": settings.location_slug,
        "destination_table": settings.destination_table,
    }


def write_silver_csv(**context) -> dict:
    from google.cloud import storage

    source = context["ti"].xcom_pull(task_ids="resolve_source_prefix")
    settings = load_settings()
    ingested_at = datetime.now(timezone.utc)
    client = storage.Client()
    bucket = client.bucket(source["bucket"])
    blobs = [
        blob
        for blob in client.list_blobs(source["bucket"], prefix=source["prefix"])
        if blob.name.endswith(".json")
    ]
    if not blobs:
        raise RuntimeError(f"No JSON files under gs://{source['bucket']}/{source['prefix']}")

    rows = []
    rejected = 0
    for blob in blobs:
        source_object = f"gs://{source['bucket']}/{blob.name}"
        try:
            payload = json.loads(blob.download_as_bytes().decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            rejected += 1
            LOGGER.warning("Skipped %s: invalid JSON (%s)", source_object, exc)
            continue

        row, reason = flatten_record(payload, source_object, ingested_at)
        if row is None:
            rejected += 1
            LOGGER.warning("Skipped %s: %s", source_object, reason)
            continue
        rows.append(row)

    rows, duplicate_count = _drop_duplicates(rows)
    rejected += duplicate_count
    if not rows:
        raise RuntimeError("No valid records remained after validation")

    hour = _hour_from_prefix(source["prefix"]) or ingested_at
    run_ts = str(context["ts_nodash"])
    object_name = (
        f"silver/weather/realtime/{settings.location_slug}/"
        f"{hour:%Y}/{hour:%m}/{hour:%d}/{hour:%H}/{run_ts}.csv"
    )
    bucket.blob(object_name).upload_from_string(
        _csv_bytes(rows),
        content_type="text/csv",
    )
    LOGGER.info(
        "Wrote gs://%s/%s with %s valid rows and %s rejected rows",
        source["bucket"],
        object_name,
        len(rows),
        rejected,
    )
    return {
        "bucket": source["bucket"],
        "object_name": object_name,
        "destination_table": source["destination_table"],
    }


def flatten_record(payload, source_object: str, ingested_at: datetime) -> tuple[dict | None, str | None]:
    if not isinstance(payload, dict):
        return None, "payload is not a JSON object"
    data = payload.get("data")
    location = payload.get("location")
    if not isinstance(data, dict):
        return None, "data section is missing or is not an object"
    if not isinstance(location, dict):
        return None, "location section is missing or is not an object"
    values = data.get("values")
    if not isinstance(values, dict):
        return None, "data.values is missing or is not an object"

    location_name = location.get("name")
    if not isinstance(location_name, str) or not location_name.strip():
        return None, "location.name is required"
    event_time = _timestamp(data.get("time"))
    if event_time is None:
        return None, "data.time is missing or is not a timestamp"

    row = {column: "" for column in CSV_COLUMNS}
    row["source_object"] = source_object
    row["event_time"] = event_time
    row["location_name"] = location_name.strip()
    row["location_lat"] = _optional_number(location.get("lat"))
    row["location_lon"] = _optional_number(location.get("lon"))
    location_type = location.get("type")
    row["location_type"] = location_type if isinstance(location_type, str) else ""
    row["ingested_at_utc"] = ingested_at.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    for field_name, column_name in WEATHER_FIELDS.items():
        if field_name not in values or values[field_name] is None:
            continue
        number = _required_number(values[field_name])
        if number is None:
            return None, f"{field_name} is present but is not numeric"
        low, high = VALUE_RANGES[field_name]
        if number < low or number > high:
            return None, f"{field_name}={number} is outside {low}..{high}"
        row[column_name] = number

    return row, None


def _normalize_prefix(source_path: str, bucket: str) -> str:
    path = source_path.strip()
    if not path:
        return ""
    if path.startswith("gs://"):
        without_scheme = path[5:]
        path_bucket, separator, remainder = without_scheme.partition("/")
        if not separator or path_bucket != bucket:
            raise RuntimeError(f"source_path must point at bucket {bucket}")
        path = remainder
    path = path.lstrip("/")
    if path and not path.endswith("/") and not path.endswith(".json"):
        path = f"{path}/"
    return path


def _previous_hour_prefix(location_slug: str, now: datetime | None = None) -> str:
    moment = now or datetime.now(timezone.utc)
    previous = moment - timedelta(hours=1)
    return (
        f"bronze/weather/realtime/{location_slug}/"
        f"{previous:%Y}/{previous:%m}/{previous:%d}/{previous:%H}/"
    )


def _hour_from_prefix(prefix: str) -> datetime | None:
    match = HOUR_IN_PREFIX.search(prefix)
    if match is None:
        return None
    year, month, day, hour = (int(part) for part in match.groups())
    return datetime(year, month, day, hour, tzinfo=timezone.utc)


def _timestamp(value) -> str | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _required_number(value) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _optional_number(value) -> float | str:
    number = _required_number(value)
    return "" if number is None else number


def _drop_duplicates(rows: list[dict]) -> tuple[list[dict], int]:
    kept = []
    seen = set()
    duplicates = 0
    for row in rows:
        key = (row["location_name"], row["event_time"])
        if key in seen:
            duplicates += 1
            LOGGER.warning("Dropped duplicate for %s at %s", *key)
            continue
        seen.add(key)
        kept.append(row)
    return kept, duplicates


def _csv_bytes(rows: list[dict]) -> bytes:
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=CSV_COLUMNS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue().encode("utf-8")
