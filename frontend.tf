# 建立前端 GCS bucket，作為靜態網站托管位置
resource "google_storage_bucket" "frontend_bucket" {
  name          = "attendance-frontend-static-site"
  location      = "ASIA"
  storage_class = "STANDARD"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
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

# 輸出網址
output "frontend_bucket_url" {
  value = "https://${google_storage_bucket.frontend_bucket.name}.storage.googleapis.com"
}