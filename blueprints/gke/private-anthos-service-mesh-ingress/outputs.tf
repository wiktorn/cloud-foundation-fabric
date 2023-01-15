# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "gke_project_id" {
  description = "Name of the service project for GKE"
  value       = module.project-svc-gke.project_id
}

output "gke_zone" {
  description = "Zone where GKE project resides"
  value       = module.cluster-1.location
}

output "ingress_dns" {
  description = "DNS name of Cloud Endpoint reserved for GKE Ingress"
  value       = google_endpoints_service.ingress_endpoint.dns_address
}

output "ingress_static_ip" {
  description = "IP Address reserved for Internal Load Balancer"
  value       = google_compute_address.ingress_static_ip.address
}

output "region" {
  description = "Region used for all resources"
  value       = var.region
}

