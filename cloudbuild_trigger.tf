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

  depends_on = [
    google_project_iam_member.cloudbuild_storage_admin,
    google_project_iam_member.cloudbuild_service_account_user,
    google_project_service.required_apis
  ]
}
