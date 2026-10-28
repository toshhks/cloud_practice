resource "google_cloud_run_service_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.ingest.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_service_account_iam_member" "scheduler_token_creator" {
  service_account_id = google_service_account.scheduler.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
}

resource "google_cloud_scheduler_job" "ingest" {
  name             = local.scheduler_job_name
  project          = var.project_id
  region           = var.region
  schedule         = "*/10 * * * *"
  time_zone        = "Etc/UTC"
  attempt_deadline = "60s"

  http_target {
    uri         = google_cloudfunctions2_function.ingest.service_config[0].uri
    http_method = "POST"
    body        = base64encode("{}")

    oidc_token {
      service_account_email = google_service_account.scheduler.email
      audience              = google_cloudfunctions2_function.ingest.service_config[0].uri
    }
  }

  depends_on = [
    google_cloud_run_service_iam_member.scheduler_invoker,
    google_service_account_iam_member.scheduler_token_creator,
    google_project_service.required,
  ]
}
