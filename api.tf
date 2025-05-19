# 啟用所有需要的 API
resource "google_project_service" "required_apis" {
  for_each = toset([
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
    "compute.googleapis.com",              # Compute Engine API
    "sqladmin.googleapis.com",             # Cloud SQL Admin API
    "servicenetworking.googleapis.com",    # Service Networking API
    "storage.googleapis.com",              # Cloud Storage API
    "secretmanager.googleapis.com",        # Secret Manager API
  ])

  project            = "tsmc-attendance-system-458811"
  service            = each.key
  disable_on_destroy = false
}