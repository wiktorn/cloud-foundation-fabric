/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# tfdoc:file:description Anthos Service Mesh resources


locals {
  gateway_dns_name = "${var.gateway_dns}.endpoints.${module.fleet_project.project_id}.cloud.goog"
}

resource "google_compute_address" "ingress_static_ip" {
  project      = module.fleet_project.project_id
  name         = "static-ingress-ip"
  subnetwork   = module.svpc.subnets["${var.region}/${var.gateway_static_ip.subnet}"].id
  address_type = "INTERNAL"
  address      = var.gateway_static_ip.ip
  region       = var.region
}

resource "google_endpoints_service" "ingress_endpoint" {
  project        = module.fleet_project.project_id
  service_name   = local.gateway_dns_name
  openapi_config = <<EOL
swagger: "2.0"
info:
  description: "Cloud Endpoints DNS"
  title: "Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "${local.gateway_dns_name}"
x-google-endpoints:
- name: "${local.gateway_dns_name}"
  target: "${google_compute_address.ingress_static_ip.address}"
EOL
}

# SSL Certificate
resource "tls_private_key" "loadbalancer" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "loadbalancer" {
  private_key_pem = tls_private_key.loadbalancer.private_key_pem
  subject {
    common_name  = local.gateway_dns_name
    organization = "Example"
  }
  validity_period_hours = 30 * 24
  allowed_uses          = ["server_auth"]
}

resource "local_sensitive_file" "kubectl_ssl_secret" {
  filename = "ansible/roles/config-mgmt/tasks/deploy-secret.yaml"
  content  = <<EOF
- name: Create Kubernetes secret with TLS certificate
  shell:
    cmd: |
      cat <<EOG | kubectl apply --context {{ context }} -n sample -f -
      apiVersion: v1
      kind: Secret
      type: kubernetes.io/tls
      metadata:
        name: lb-tls-certificate
      data:
        tls.crt: ${base64encode(tls_self_signed_cert.loadbalancer.cert_pem)}
        tls.key: ${base64encode(tls_private_key.loadbalancer.private_key_pem)}
      EOG
EOF
}