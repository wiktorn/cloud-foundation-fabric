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

variable "billing_account_id" {
  description = "Billing account id."
  type        = string
}

variable "clusters_config" {
  description = "Clusters configuration."
  type = map(object({
    subnet_cidr_block   = string
    master_cidr_block   = string
    services_cidr_block = string
    pods_cidr_block     = string
  }))
  default = {
    cluster-a = {
      subnet_cidr_block   = "10.0.1.0/24"
      master_cidr_block   = "10.16.0.0/28"
      services_cidr_block = "192.168.1.0/24"
      pods_cidr_block     = "172.16.0.0/20"
    }
    cluster-b = {
      subnet_cidr_block   = "10.0.2.0/24"
      master_cidr_block   = "10.16.0.16/28"
      services_cidr_block = "192.168.2.0/24"
      pods_cidr_block     = "172.16.16.0/20"
    }
  }
}

variable "gateway_static_ip" {
  description = "IP address of Gateway into GKE. Needs to be a part of one defined subnets (either: subnet-mgmt or in format 'subnet-$${clusters_config.key}'"
  type = object({
    subnet = string
    ip     = string
  })
  default = {
    subnet : "subnet-mgmt"
    ip : "10.0.0.10"
  }
}

variable "gateway_dns" {
  description = "DNS hostname of Gateway into GKE."
  default     = "ingress"
}


variable "istio_version" {
  description = "ASM version."
  type        = string
  default     = "1.14.1-asm.3"
}

variable "mesh_config" {
  description = "Anthos Service Mesh related configuration"
  type = object({
    enable_mesh                 = optional(bool, false)
    provision_gateway_resources = optional(bool, false)
    provision_gateway           = optional(bool, false)
  })
  default = {}
  validation {
    condition = !(
      (
        !var.mesh_config.provision_gateway_resources && var.mesh_config.provision_gateway
        ) || (
        !var.mesh_config.enable_mesh && var.mesh_config.provision_gateway_resources && var.mesh_config.provision_gateway
      )
    )
    error_message = "provision_gateway depends on provision_gateway_resources and provision_gateway_resources depends on enable_mesh"
  }
}


variable "mgmt_server_config" {
  description = "Mgmt server configuration."
  type = object({
    disk_size     = number
    disk_type     = string
    image         = string
    instance_type = string
    region        = string
    zone          = string
  })
  default = {
    disk_size     = 50
    disk_type     = "pd-ssd"
    image         = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    instance_type = "n1-standard-2"
    region        = "europe-west1"
    zone          = "europe-west1-c"
  }
}

variable "mgmt_subnet_cidr_block" {
  description = "Management subnet CIDR block."
  type        = string
  default     = "10.0.0.0/28"
}

variable "parent" {
  description = "Parent."
  type        = string
}

variable "prefix" {
  description = "Prefix for project names"
  type        = string
}

variable "proxy_only_cidr" {
  description = "Private IP address range for proxy-only subnet for Internal Load Balancer (used only when Service Mesh is enabled)"
  type        = string
  default     = "10.32.0.0/23"
}

variable "region" {
  description = "Region."
  type        = string
  default     = "europe-west1"
}
