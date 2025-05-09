resource "google_compute_network" "attendance_vpc" {
  name = "attendance-vpc"
  auto_create_subnetworks = true

  depends_on = [google_project_service.required_apis]
}

# Reserve IP range for Google services
resource "google_compute_global_address" "private_ip_range" {
  name          = "attendance-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16  # /16 CIDR
  network       = google_compute_network.attendance_vpc.id
  
  depends_on = [google_project_service.required_apis]
}

# Establish a VPC peer connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.attendance_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
  
  depends_on = [google_compute_global_address.private_ip_range]
}
