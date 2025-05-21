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
    tier = "db-f1-micro" # Smallest tier, good for development
    availability_type = "REGIONAL" # Multi availability zone

    # Automatically increase storage as needed
    disk_autoresize = true
    disk_size       = 10 # Initial size in GB
    disk_type       = "PD_HDD"

    # Disable backup
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
      start_time         = "22:00"
    }

    # IP configuration
    ip_configuration {
      ipv4_enabled    = true # Pulbic IP
      private_network = google_compute_network.attendance_vpc.id

      authorized_networks {
        name  = "cloudsqlproxy"
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

data "google_secret_manager_secret_version" "db_user" {
  secret = "DB_USER"
}

data "google_secret_manager_secret_version" "db_pass" {
  secret = "DB_PASS"
}

# Create a user
resource "google_sql_user" "attendance_user" {
  name        = data.google_secret_manager_secret_version.db_user.secret_data
  instance    = google_sql_database_instance.attendance_mysql.name
  password_wo = data.google_secret_manager_secret_version.db_pass.secret_data
  # user password_wo instead of password
}