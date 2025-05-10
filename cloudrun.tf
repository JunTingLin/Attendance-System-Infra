# cloudrun.tf

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
  max_instances = 4

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

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Initial placeholder image

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
        value = "Attendance_System"
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
    }

    # VPC access configuration
    vpc_access {
      connector = google_vpc_access_connector.attendance_connector.id
      egress    = "PRIVATE_RANGES_ONLY" # Only route private IP ranges through VPC
    }

    service_account = "terraform-junting@tsmc-attendance-system-458811.iam.gserviceaccount.com"

    # Add Cloud SQL connection via proxy
    scaling {
      max_instance_count = 10
    }
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

# Create Cloud Build trigger for GitHub repository - Second generation connection method
resource "google_cloudbuild_trigger" "minimal_trigger" {
  name = "minimal-trigger"
  
  # 明確指定 location
  location = "global"
  
  # 使用絕對最簡單的 GitHub 配置
  github {
    owner = "JunTingLin"
    name = "Attendance-System-API"
    push {
      branch = "main"  # 不使用正則表達式，只用簡單字符串
    }
  }
  
  # 使用最簡單的構建步驟，避免變數
  build {
    step {
      name = "ubuntu"
      args = ["echo", "Hello World"]
    }
  }
}