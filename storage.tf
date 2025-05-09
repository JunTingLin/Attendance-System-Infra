# Create GCS bucket
resource "google_storage_bucket" "attendance_system_bucket" {
  name          = "attendance-system-files"
  location      = "ASIA"
  storage_class = "STANDARD"
  
  # Wait for Storage API to be enabled
  depends_on = [google_project_service.storage_api]
}