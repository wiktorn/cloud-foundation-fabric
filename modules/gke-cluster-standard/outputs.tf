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

output "ca_certificate" {
  description = "Public certificate of the cluster (base64-encoded)."
  value = (
    google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  )
  sensitive = true
}

output "cluster" {
  description = "Cluster resource."
  sensitive   = true
  value       = google_container_cluster.cluster
}

output "dns_endpoint" {
  description = "Control plane DNS endpoint."
  value = try(
    google_container_cluster.cluster.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint,
    null
  )
}

output "endpoint" {
  description = "Cluster endpoint."
  value       = google_container_cluster.cluster.endpoint
}

output "id" {
  description = "FUlly qualified cluster id."
  value       = google_container_cluster.cluster.id
}

output "location" {
  description = "Cluster location."
  value       = google_container_cluster.cluster.location
}

output "master_version" {
  description = "Master version."
  value       = google_container_cluster.cluster.master_version
}

output "name" {
  description = "Cluster name."
  value       = google_container_cluster.cluster.name
}

output "notifications" {
  description = "GKE PubSub notifications topic."
  value       = try(google_pubsub_topic.notifications[0].id, null)
}

output "self_link" {
  description = "Cluster self link."
  sensitive   = true
  value       = google_container_cluster.cluster.self_link
}

output "workload_identity_pool" {
  description = "Workload identity pool."
  value       = "${var.project_id}.svc.id.goog"
  depends_on = [
    google_container_cluster.cluster
  ]
}
