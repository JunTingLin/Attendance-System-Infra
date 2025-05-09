provider "google" {
  project = "tsmc-attendance-system-458811"
  region  = "asia-east1"
}

# Enable required APIs
resource "google_project_service" "storage_api" {
  project = "tsmc-attendance-system-458811"
  service = "storage.googleapis.com"
  disable_on_destroy = false
}