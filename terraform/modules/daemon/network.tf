# Health checks
resource "google_compute_http_health_check" "daemon" {
  name = "${var.name}-explorer-http-health-check"
  request_path = (
    var.name == "bitcoin-mainnet" ? "/api/blocks/tip/hash"
    : var.name == "bitcoin-testnet" ? "/testnet/api/blocks/tip/hash"
    : var.name == "liquid-testnet" ? "/liquidtestnet/api/blocks/tip/hash"
    : "/liquid/api/blocks/tip/hash"
  )

  timeout_sec        = 20
  check_interval_sec = 30

  count = var.create_resources
}

resource "google_compute_health_check" "daemon-electrs" {
  name               = "${var.name}-explorer-health-check-electrs-tcp"
  timeout_sec        = 20
  check_interval_sec = 30

  tcp_health_check {
    port = "80"
  }

  count = var.create_resources
}

# Backend services
resource "google_compute_backend_service" "daemon" {
  name        = "${var.name}-explorer-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 3600
  enable_cdn  = false
  
  security_policy = var.name == "bitcoin-mainnet" ? "https://www.googleapis.com/compute/v1/projects/${var.project}/global/securityPolicies/esplora-block-rule" : "" # TODO: add to TF

  cdn_policy {
    cache_key_policy {
      include_host = true
      include_protocol = true
      include_query_string = true
    }
  }

  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.daemon
    iterator = group
    content {
      group           = group.value.instance_group
      max_utilization = 0.8
    }
  }

  health_checks = [google_compute_http_health_check.daemon[0].self_link]
  count         = var.create_resources
}

resource "google_compute_backend_service" "daemon-electrs" {
  name        = "${var.name}-explorer-backend-service-electrs"
  protocol    = "TCP"
  port_name   = "electrs"
  timeout_sec = 60

  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.daemon
    iterator = group
    content {
      group           = group.value.instance_group
      max_utilization = 0.8
    }
  }

  health_checks = [google_compute_health_check.daemon-electrs[0].self_link]
  count         = var.create_resources
}
