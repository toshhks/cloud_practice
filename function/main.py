import os
from datetime import datetime, timezone

import functions_framework
import requests
from google.cloud import storage

REALTIME_URL = "https://api.tomorrow.io/v4/weather/realtime"


@functions_framework.http
def ingest_weather(request):
    """Fetch the current tomorrow.io conditions and store the raw body in GCS."""
    del request

    now = datetime.now(timezone.utc)
    stamp = now.strftime("%Y%m%dT%H%M%S") + f"{now.microsecond // 1000:03d}Z"
    location_slug = os.environ["LOCATION_SLUG"]
    object_name = (
        f"bronze/weather/realtime/{location_slug}/"
        f"{now:%Y}/{now:%m}/{now:%d}/{now:%H}/{stamp}.json"
    )

    response = requests.get(
        REALTIME_URL,
        params={
            "location": os.environ["LOCATION_QUERY"],
            "units": "metric",
        },
        headers={"apikey": os.environ["TOMORROW_API_KEY"]},
        timeout=30,
    )
    response.raise_for_status()

    bucket = storage.Client().bucket(os.environ["BUCKET_NAME"])
    bucket.blob(object_name).upload_from_string(
        response.content,
        content_type="application/json",
    )
    return {"object": object_name}, 200
