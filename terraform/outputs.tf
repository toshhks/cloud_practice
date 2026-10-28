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
  description = "Cloud Function name. The function is deployed in a later change."
  value       = local.function_name
}

output "scheduler_job_name" {
  description = "Cloud Scheduler job name. The job is created in a later change."
  value       = local.scheduler_job_name
}

output "service_account_ids" {
  description = "Account ids for the four service accounts. Emails appear once the accounts exist."
  value = {
    ingest    = local.ingest_sa_account_id
    scheduler = local.scheduler_sa_account_id
    airflow   = local.airflow_sa_account_id
    build     = local.build_sa_account_id
  }
}
