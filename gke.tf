# Create a GKE Cluster
resource "google_container_cluster" "monitoring_cluster" {
  name     = "monitoring-cluster"
  location = "asia-east1"
  
  # Delete the default node pool; we will create a custom node pool.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Using an existing VPC
  network = google_compute_network.attendance_vpc.self_link
  
  # Let GCP automatically allocate IP ranges to avoid conflicts.
  ip_allocation_policy {}
  
  # Optional: Turn on the private cluster (if higher security is required)
  # private_cluster_config {
  #   enable_private_nodes    = true
  #   enable_private_endpoint = false
  #   master_ipv4_cidr_block  = "172.16.0.0/28"
  # }
  
  depends_on = [
    google_project_service.required_apis,
    google_compute_network.attendance_vpc
  ]

  deletion_protection = false
}

# Create Node Pool
resource "google_container_node_pool" "monitoring_nodes" {
  name       = "monitoring-node-pool"
  location   = "asia-east1"
  cluster    = google_container_cluster.monitoring_cluster.name
  node_count = 1
  
  node_config {
    machine_type = "e2-medium"
    
    # Add the permissions required to execute Alloy.
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}