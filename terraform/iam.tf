resource "google_service_account" "ingest" {
  account_id   = local.ingest_sa_account_id
  project      = var.project_id
  display_name = "Weather ingest"
  description  = "Runtime identity for the bronze ingest function."

  depends_on = [google_project_service.required]
}

resource "google_service_account" "scheduler" {
  account_id   = local.scheduler_sa_account_id
  project      = var.project_id
  display_name = "Weather scheduler"
  description  = "Invokes the ingest function on a schedule. run.invoker is granted with the function."

  depends_on = [google_project_service.required]
}

resource "google_service_account" "airflow" {
  account_id   = local.airflow_sa_account_id
  project      = var.project_id
  display_name = "Weather airflow"
  description  = "Local Airflow identity for bronze, silver, and the gold BigQuery table."

  depends_on = [google_project_service.required]
}

resource "google_service_account" "build" {
  account_id   = local.build_sa_account_id
  project      = var.project_id
  display_name = "Weather function build"
  description  = "Builds the Cloud Function. New projects do not grant this to the default Cloud Build account."

  depends_on = [google_project_service.required]
}
