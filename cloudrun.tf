# 獲取專案編號
data "google_project" "project" {
  project_id = "tsmc-attendance-system-458811"
}

# 定義服務帳戶變數
locals {
  cloudbuild_sa = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  terraform_sa = "serviceAccount:terraform-junting@tsmc-attendance-system-458811.iam.gserviceaccount.com"
}

# 授予 Terraform 服務帳戶 Storage Admin 權限
resource "google_project_iam_member" "terraform_storage_admin" {
  project = "tsmc-attendance-system-458811"
  role    = "roles/storage.admin"
  member  = local.terraform_sa
}

# 授予 Cloud Build 服務帳戶所有必要權限
resource "google_project_iam_member" "cloudbuild_storage_admin" {
  project = "tsmc-attendance-system-458811"
  role    = "roles/storage.admin"
  member  = local.cloudbuild_sa
}

resource "google_project_iam_member" "cloudbuild_artifact_admin" {
  project = "tsmc-attendance-system-458811"
  role    = "roles/artifactregistry.admin"
  member  = local.cloudbuild_sa
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = "tsmc-attendance-system-458811"
  role    = "roles/run.admin"
  member  = local.cloudbuild_sa
}

resource "google_project_iam_member" "cloudbuild_service_account_user" {
  project = "tsmc-attendance-system-458811"
  role    = "roles/iam.serviceAccountUser"
  member  = local.cloudbuild_sa
}

# Enable required APIs for Cloud Run and related services
resource "google_project_service" "cloudrun_apis" {
  for_each = toset([
    "run.googleapis.com",              # Cloud Run API
    "cloudbuild.googleapis.com",       # Cloud Build API
    "artifactregistry.googleapis.com", # Artifact Registry API
    "vpcaccess.googleapis.com",        # Serverless VPC Access API
  ])

  project            = "tsmc-attendance-system-458811"
  service            = each.key
  disable_on_destroy = false

  depends_on = [google_project_service.required_apis]
}

# Create Serverless VPC Access connector for Cloud Run
resource "google_vpc_access_connector" "attendance_connector" {
  name          = "attendance-vpc-connector"
  region        = "asia-east1"
  ip_cidr_range = "10.8.0.0/28" # CIDR range for VPC connector
  network       = google_compute_network.attendance_vpc.name

  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.cloudrun_apis]
}

# Create Artifact Registry repository for container images
resource "google_artifact_registry_repository" "attendance_repo" {
  location      = "asia-east1"
  repository_id = "attendance-system"
  format        = "DOCKER"

  depends_on = [google_project_service.cloudrun_apis]
}

# Create Cloud Run service
resource "google_cloud_run_v2_service" "attendance_service" {
  name     = "attendance-system-api"
  location = "asia-east1"
  deletion_protection = false

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Initial placeholder image

      resources {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }

      # Environment variables (some is from Secret Manager)
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "prod"
      }

      env {
        name  = "CLOUD_SQL_INSTANCE"
        value = google_sql_database_instance.attendance_mysql.connection_name
      }

      env {
        name  = "DB_NAME"
        value = "attendance_system"
      }

      env {
        name = "DB_USER"
        value_source {
          secret_key_ref {
            secret  = "DB_USER"
            version = "latest"
          }
        }
      }

      env {
        name = "DB_PASS"
        value_source {
          secret_key_ref {
            secret  = "DB_PASS"
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = "JWT_SECRET"
            version = "latest"
          }
        }
      }

      env {
        name  = "GCS_BUCKET_NAME"
        value = google_storage_bucket.attendance_system_bucket.name
      }

      env {
        name = "TELEGRAM_BOT_TOKEN"
        value_source {
          secret_key_ref {
            secret  = "TELEGRAM_BOT_TOKEN"
            version = "latest"
          }
        }
      }

      env {
        name  = "SERVER_PORT"
        value = "8080"
      }

      env {
        name = "OTEL_EXPORTER_OTLP_HEADERS"
        value_source {
          secret_key_ref {
            secret  = "OTEL_EXPORTER_OTLP_HEADERS"
            version = "latest"
          }
        }
      }
      env {
        name  = "OTEL_RESOURCE_ATTRIBUTES"
        value = "service.name=attendance-system,service.namespace=2025.tsmc.cloudnative,deployment.environment=production"
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "https://otlp-gateway-prod-ap-northeast-0.grafana.net/otlp"
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = "http/protobuf"
      }

    }

    # define a volume that points to your Cloud SQL instance
    volumes {
      name = "cloudsql"

      cloud_sql_instance {
        instances = [
          google_sql_database_instance.attendance_mysql.connection_name,
        ]
      }
    }
  

    # VPC access configuration
    vpc_access {
      connector = google_vpc_access_connector.attendance_connector.id
      egress    = "PRIVATE_RANGES_ONLY" # Only route private IP ranges through VPC
    }

    service_account = "terraform-junting@tsmc-attendance-system-458811.iam.gserviceaccount.com"


    scaling {
      min_instance_count = 2
      max_instance_count = 10
    }
  }

  
  lifecycle {
    ignore_changes = [
      # 忽略 image 欄位變動，讓 Cloud Build 去更新
      # 長遠來說還是把映像版本透過變數下發、並由 Terraform 管理最乾淨
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_project_service.cloudrun_apis,
    google_vpc_access_connector.attendance_connector,
    google_sql_database_instance.attendance_mysql,
    google_storage_bucket.attendance_system_bucket
  ]
}

# Allow public access to Cloud Run service
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.attendance_service.location
  name     = google_cloud_run_v2_service.attendance_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloudbuild_trigger" "attendance_build_trigger" {
  name        = "attendance-build-trigger"
  description = "Trigger for building and deploying Attendance System from GitHub"
  

  service_account = "projects/tsmc-attendance-system-458811/serviceAccounts/terraform-junting@tsmc-attendance-system-458811.iam.gserviceaccount.com"

  github {
    owner = "JunTingLin"
    name  = "Attendance-System-API"
    push {
      branch = "^main$"
    }
  }
  
  filename = "cloudbuild.yaml"
  
  depends_on = [
    google_project_iam_member.cloudbuild_storage_admin,
    google_project_iam_member.cloudbuild_artifact_admin,
    google_project_iam_member.cloudbuild_run_admin,
    google_project_iam_member.cloudbuild_service_account_user
  ]
}