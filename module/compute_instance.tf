# Compute instance running monitoring tool prometheus
# Antman - Milky Way

# Compute Instance Linux OS
resource "google_compute_instance" "prometheus_server" {
  name         = "prometheus-standalone-vm"
  machine_type = "e2-medium" # 2 vCPUs, 4GB RAM is a solid baseline for learning
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Linux distro
      size  = 30                       # 30 GB disk space for OS + metrics storage - data
      type  = "pd-ssd"                 # SSD for peak performance
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.prometheus_ip.address # Assign the static IP
    }
  }

# Bash script installs and runs Prometheus when the VM boots up
  metadata_startup_script = <<-EOT
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y wget tar

    # Create a dedicated system user for Prometheus
    sudo useradd --no-create-home --shell /bin/false prometheus

    # Download the open-source Prometheus binary
    cd /tmp
    wget https://github.com
    tar -xvf prometheus-2.51.0.linux-amd64.tar.gz
    
    # Move binaries and set permissions
    sudo mv prometheus-2.51.0.linux-amd64/prometheus /usr/local/bin/
    sudo mv prometheus-2.51.0.linux-amd64/promtool /usr/local/bin/
    sudo chown prometheus:prometheus /usr/local/bin/prometheus
    sudo chown prometheus:prometheus /usr/local/bin/promtool

    # Create configuration and data directories
    sudo mkdir /etc/prometheus
    sudo mkdir /var/lib/prometheus
    sudo chown prometheus:prometheus /var/lib/prometheus

    # Create a basic configuration file (prometheus.yml)
    cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'prometheus_self'
        static_configs:
          - targets: ['localhost:9090']
    EOF
    sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

    # Create a systemd service file to run Prometheus as a background service
    cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
    [Unit]
    Description=Prometheus
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=prometheus
    Group=prometheus
    Type=simple
    ExecStart=/usr/local/bin/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/var/lib/prometheus/

    [Install]
    WantedBy=multi-user.target
    EOF

    # Start and enable Prometheus service
    sudo systemctl daemon-reload
    sudo systemctl enable prometheus
    sudo systemctl start prometheus
  EOT

  # Tag the VM so your firewall rules can find it
  tags = ["prometheus-monitoring"]
}

# Firewall Rule to allow access to the Prometheus Web UI (Port 9090)
resource "google_compute_firewall" "allow_prometheus_ui" {
  name    = "allow-prometheus-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["9090"]
  }

  source_ranges = ["0.0.0.0/0"] # Open to the public web (restrict this to your IP for security!)
  target_tags   = ["prometheus-monitoring"]
}
