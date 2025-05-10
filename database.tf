# Enable Cloud SQL Admin API
resource "google_project_service" "sql_api" {
  project = "tsmc-attendance-system-458811"
  service = "sqladmin.googleapis.com"
  disable_on_destroy = false
}


# Create a MySQL instance
resource "google_sql_database_instance" "attendance_mysql" {
  name             = "attendance-mysql-instance"
  region           = "asia-east1"
  database_version = "MYSQL_8_0"
  
  depends_on = [
    google_project_service.required_apis,
    google_service_networking_connection.private_vpc_connection
  ]
  
  settings {
    tier = "db-f1-micro"  # Smallest tier, good for development
    
    # Automatically increase storage as needed
    disk_autoresize = true
    disk_size       = 10  # Initial size in GB
    disk_type       = "PD_HDD"
    
    # Disable backup
    backup_configuration {
      enabled            = false
      binary_log_enabled = false  # Disable point-in-time recovery
    }
    
    # IP configuration
    ip_configuration {
      ipv4_enabled = true   # Pulbic IP
      private_network = google_compute_network.attendance_vpc.id

      authorized_networks {
        name = "cloudsqlproxy"
        value = "0.0.0.0/0"
      }
    }
  }
  
  # Delete protection
  deletion_protection = false
}

# Create a database
resource "google_sql_database" "attendance_db" {
  name     = "attendance_system"
  instance = google_sql_database_instance.attendance_mysql.name
}

data "google_secret_manager_secret_version" "attendance_app_password" {
  secret = "attendance_app"
}

# Create a user
resource "google_sql_user" "attendance_user" {
  name     = "attendance_app"
  instance = google_sql_database_instance.attendance_mysql.name
  password_wo = data.google_secret_manager_secret_version.attendance_app_password.secret_data
  # user password_wo instead of password
}