provider "google" {
  project = "tsmc-attendance-system-458811"
  region  = "asia-east1"
}

terraform {
  # Configure Terraform to store state in GCS
  backend "gcs" {
    bucket = "attendance-system-terraform-state"    # <— replace with your bucket name
    prefix = "infra/state"                          # <— path inside bucket for tfstate file
  }
}