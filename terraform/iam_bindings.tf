locals {
  bucket_resource_name = "projects/_/buckets/${google_storage_bucket.weather.name}"
  bucket_objects_name  = "${local.bucket_resource_name}/objects"
}

resource "google_secret_manager_secret_iam_member" "ingest_secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.tomorrow_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingest.email}"
}

resource "google_storage_bucket_iam_member" "ingest_bronze_creator" {
  bucket = google_storage_bucket.weather.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.ingest.email}"

  condition {
    title       = "bronze_objects"
    description = "Create objects only under bronze/."
    expression  = "resource.name.startsWith('${local.bucket_objects_name}/bronze/')"
  }
}

resource "google_project_iam_member" "ingest_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.ingest.email}"
}

resource "google_storage_bucket_iam_member" "airflow_layer_reader" {
  bucket = google_storage_bucket.weather.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.airflow.email}"

  condition {
    title       = "bronze_and_silver_objects"
    description = "Read bronze and silver objects. Listing is bucket-scoped, so object names outside these prefixes can be listed but not read."
    expression  = <<-EOT
      resource.name.startsWith("${local.bucket_objects_name}/bronze/") ||
      resource.name.startsWith("${local.bucket_objects_name}/silver/") ||
      resource.name == "${local.bucket_resource_name}"
    EOT
  }
}

resource "google_storage_bucket_iam_member" "airflow_silver_writer" {
  bucket = google_storage_bucket.weather.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.airflow.email}"

  condition {
    title       = "silver_objects"
    description = "Create, read, and replace objects only under silver/."
    expression  = "resource.name.startsWith('${local.bucket_objects_name}/silver/')"
  }
}

resource "google_project_iam_member" "airflow_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.airflow.email}"
}

resource "google_bigquery_dataset_iam_member" "airflow_data_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.weather.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.airflow.email}"
}

resource "google_project_iam_member" "build_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.build.email}"
}

resource "google_project_iam_member" "build_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.build.email}"
}

resource "google_storage_bucket_iam_member" "build_source_reader" {
  bucket = google_storage_bucket.weather.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.build.email}"

  condition {
    title       = "function_source_objects"
    description = "Read the function source zip under functions/."
    expression  = <<-EOT
      resource.name.startsWith("${local.bucket_objects_name}/functions/") ||
      resource.name == "${local.bucket_resource_name}"
    EOT
  }
}

resource "google_service_account_iam_member" "build_acts_as_ingest" {
  service_account_id = google_service_account.ingest.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.build.email}"
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_service_account_iam_member" "functions_agent_acts_as_ingest" {
  service_account_id = google_service_account.ingest.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcf-admin-robot.iam.gserviceaccount.com"
}
