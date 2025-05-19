# 建立前端 GCS bucket，作為靜態網站托管位置
resource "google_storage_bucket" "frontend_bucket" {
  name          = "attendance-frontend-static-site"
  location      = "ASIA"
  storage_class = "STANDARD"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }


  force_destroy = true
  uniform_bucket_level_access = true

  depends_on = [google_project_service.required_apis]
}

# 開放所有人可存取
resource "google_storage_bucket_iam_member" "frontend_public_access" {
  bucket = google_storage_bucket.frontend_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

data "google_secret_manager_secret" "frontend_api_url" {
  secret_id = "API_URL"
}


resource "google_cloudbuild_trigger" "frontend_build_trigger" {
  name        = "frontend-build-trigger"
  description = "Trigger for building and deploying Attendance Frontend (1st Gen)"
  location    = "global"

  service_account = "projects/tsmc-attendance-system-458811/serviceAccounts/terraform-junting@tsmc-attendance-system-458811.iam.gserviceaccount.com"

  github {
    owner = "jhen-fang"
    name  = "Attendance-System-frontend"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
  disabled = true

  depends_on = [
    google_project_iam_member.cloudbuild_storage_admin,
    google_project_iam_member.cloudbuild_service_account_user,
    google_project_service.required_apis
  ]
}