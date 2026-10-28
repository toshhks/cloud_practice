locals {
  gold_schema = [
    {
      name        = "source_object"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Source path of the bronze file this row came from."
    },
    {
      name        = "event_time"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Value from the data.time field."
    },
    {
      name        = "location_name"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Location name from the weather payload."
    },
    {
      name        = "location_lat"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Location latitude."
    },
    {
      name        = "location_lon"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Location longitude."
    },
    {
      name        = "location_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Location type from the weather payload."
    },
    {
      name        = "ingested_at_utc"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "UTC time when the row was processed."
    },
    {
      name        = "weather_temperature"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Temperature."
    },
    {
      name        = "weather_humidity"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Humidity."
    },
    {
      name        = "weather_windSpeed"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Wind speed."
    },
    {
      name        = "weather_cloudCover"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Cloud cover."
    },
    {
      name        = "weather_precipitationProbability"
      type        = "FLOAT64"
      mode        = "NULLABLE"
      description = "Precipitation probability."
    },
  ]
}

resource "google_bigquery_dataset" "weather" {
  dataset_id                 = local.dataset_id
  project                    = var.project_id
  location                   = var.region
  labels                     = local.labels
  delete_contents_on_destroy = false

  depends_on = [google_project_service.required]
}

resource "google_bigquery_table" "realtime_gold" {
  dataset_id          = google_bigquery_dataset.weather.dataset_id
  table_id            = local.table_id
  project             = var.project_id
  labels              = local.labels
  deletion_protection = true
  schema              = jsonencode(local.gold_schema)
}
