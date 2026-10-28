locals {
  name_prefix = "weather-${var.env}"

  bucket_name        = "${local.name_prefix}-${var.project_id}"
  secret_id          = "${local.name_prefix}-tomorrow-api-key"
  dataset_id         = "weather_${var.env}"
  table_id           = "realtime_gold"
  function_name      = "${local.name_prefix}-ingest"
  scheduler_job_name = "${local.name_prefix}-ingest"

  ingest_sa_account_id    = "weather-ingest"
  scheduler_sa_account_id = "weather-scheduler"
  airflow_sa_account_id   = "weather-airflow"
  build_sa_account_id     = "weather-build"
}

output "project_id" {
  description = "GCP project that hosts the stack."
  value       = var.project_id
}

output "region" {
  description = "Region for the function and the scheduler."
  value       = var.region
}

output "bucket_name" {
  description = "GCS bucket for bronze JSON and silver CSV."
  value       = google_storage_bucket.weather.name
}

output "secret_id" {
  description = "Secret Manager id for the tomorrow.io API key. The version is added outside Terraform."
  value       = google_secret_manager_secret.tomorrow_api_key.secret_id
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset that holds the gold table."
  value       = google_bigquery_dataset.weather.dataset_id
}

output "bigquery_table_id" {
  description = "BigQuery gold table id."
  value       = "${google_bigquery_dataset.weather.dataset_id}.${google_bigquery_table.realtime_gold.table_id}"
}

output "function_name" {
  description = "Cloud Function name."
  value       = google_cloudfunctions2_function.ingest.name
}

output "function_uri" {
  description = "HTTPS URL of the ingest function. Only the scheduler service account can invoke it."
  value       = google_cloudfunctions2_function.ingest.service_config[0].uri
}

output "scheduler_job_name" {
  description = "Cloud Scheduler job that calls the function every 10 minutes."
  value       = google_cloud_scheduler_job.ingest.name
}

output "service_account_emails" {
  description = "Service account emails."
  value = {
    ingest    = google_service_account.ingest.email
    scheduler = google_service_account.scheduler.email
    airflow   = google_service_account.airflow.email
    build     = google_service_account.build.email
  }
}
