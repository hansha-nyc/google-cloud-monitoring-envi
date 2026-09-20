# Google Cloud Provider
# Antman - Milky Way

provider "google" {
  project = "your-gcp-project-id"
  region  = "us-central1"
}

# Reserve a static external IP so your Prometheus UI URL doesn't change on reboot
resource "google_compute_address" "prometheus_ip" {
  name   = "prometheus-static-ip"
  region = "us-central1"
}
