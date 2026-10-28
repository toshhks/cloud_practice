resource "google_secret_manager_secret" "tomorrow_api_key" {
  secret_id = local.secret_id
  project   = var.project_id
  labels    = local.labels

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.required]
}
