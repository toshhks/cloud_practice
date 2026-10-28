# The tomorrow.io secret must already have a version before apply.
# Terraform stores the zip and the function, not the API key.

data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/.build/function.zip"
  excludes    = ["__pycache__", "*.pyc"]
}

resource "google_storage_bucket_object" "function_source" {
  name   = "functions/weather-ingest/${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.weather.name
  source = data.archive_file.function_source.output_path
}

resource "google_cloudfunctions2_function" "ingest" {
  name     = local.function_name
  location = var.region
  project  = var.project_id
  labels   = local.labels

  build_config {
    runtime         = "python312"
    entry_point     = "ingest_weather"
    service_account = google_service_account.build.id

    source {
      storage_source {
        bucket = google_storage_bucket.weather.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 60
    max_instance_count    = 1
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.ingest.email

    environment_variables = {
      BUCKET_NAME    = google_storage_bucket.weather.name
      LOCATION_SLUG  = var.location_slug
      LOCATION_QUERY = var.location_query
    }

    secret_environment_variables {
      key        = "TOMORROW_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.tomorrow_api_key.secret_id
      version    = "latest"
    }
  }

  depends_on = [
    google_project_service.required,
    google_storage_bucket_iam_member.build_gcf_sources_reader,
  ]
}
