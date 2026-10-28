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
  description = "Data bucket name. The bucket itself is created in a later change."
  value       = local.bucket_name
}

output "secret_id" {
  description = "Secret Manager id for the tomorrow.io API key. No secret version is stored here."
  value       = local.secret_id
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset id for the gold table."
  value       = local.dataset_id
}

output "bigquery_table_id" {
  description = "BigQuery gold table id."
  value       = "${local.dataset_id}.${local.table_id}"
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
