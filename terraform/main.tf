terraform {
  required_providers {
    google = "~> 4.0"
  }
}

provider google {
  credentials = file("cred.json")
  project = "devops-interns"
  region = "us-central1"
}

resource "google_compute_network" "app_network_enes" {
  name = "app-network-enes"
}

resource "google_compute_subnetwork" "app_subnetwork" {
  name          = "app-subnetwork"
  ip_cidr_range = "10.13.0.0/24"
  network       = google_compute_network.app_network_enes.id
  region        =  "us-central1"
}

resource "google_compute_instance" "app_servers" {
  count = 2

  name = "app-server-${count.index + 1}"
  machine_type = "n1-standard-1"
  zone = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

    metadata = {
    ssh-keys = "debian:${file("~/.ssh/gcp.pub")}"
  } 
  network_interface {
    network   = google_compute_network.app_network_enes.name
    subnetwork = google_compute_subnetwork.app_subnetwork.name

     access_config {

    }
  }

  tags = ["app-servers-enes"]  
}

resource "google_compute_network" "load_balancer" {
  name = "load-balancer"
}

resource "google_compute_forwarding_rule" "load_balancer" {
  name = "load-balancer"

  load_balancing_scheme = "EXTERNAL"

  target = google_compute_target_pool.target_pool.self_link
  port_range = "80"
}

resource "google_compute_target_pool" "target_pool" {
  name = "target-pool"

  instances = tolist(google_compute_instance.app_servers.*.self_link)
}

resource "google_compute_health_check" "health_check" {
  name = "my-health-check"

  check_interval_sec = 5
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port = 80
  }
}

resource "google_compute_firewall" "allow_mysql" {
  name    = "allow-mysql-enes"
  network = google_compute_network.app_network_enes.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3306"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mysql-instance-enes"]
}

resource "google_compute_firewall" "allow_app_servers" {
  name    = "allow-app-servers-enes"
  network = google_compute_network.app_network_enes.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["app-servers-enes"]
}

resource "google_compute_instance" "mysql_instance" {
  name         = "mysql-instance-enes"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

    metadata = {
    ssh-keys = "debian:${file("~/.ssh/gcp.pub")}"
  }

  network_interface {
    network   = google_compute_network.app_network_enes.name
    subnetwork = google_compute_subnetwork.app_subnetwork.name

     access_config {

    }
  } 

  tags = ["mysql-instance-enes"] 
}

output "mysql_instance_enes_ip" {
  value =  google_compute_instance.mysql_instance.network_interface[0].access_config[0].nat_ip
}
output "app_servers_enes_ips" {
  value = [for instance in google_compute_instance.app_servers : instance.network_interface[0].access_config[0].nat_ip]
}
