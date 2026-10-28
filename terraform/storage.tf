# Bronze JSON and silver CSV share this bucket.
# Paths: bronze/weather/realtime/<location>/... and silver/weather/realtime/<location>/...

resource "google_storage_bucket" "weather" {
  name                        = local.bucket_name
  project                     = var.project_id
  location                    = var.region
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.labels

  depends_on = [google_project_service.required]
}
