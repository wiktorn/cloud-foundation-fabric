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

variable "admin_user" {
  description = "Admin users for GKE"
  type        = list(string)
}

variable "bastion_owners" {
  description = "Host VPC project owners, in IAM format."
  type        = list(string)
  default     = []
}

variable "billing_account_id" {
  description = "Billing account id used as default for new projects."
  type        = string
}

variable "gke_authorized_ranges" {
  description = "Map of authorized ranges (name -> CIDR)"
  type        = map(any)
  default     = {}
}

variable "gke_master_network_ranges" {
  description = "Private service IP CIDR ranges."
  type        = map(string)
  default = {
    cluster = "192.168.0.0/28"
  }
}

variable "gke_owners" {
  description = "GKE project owners, in IAM format."
  type        = list(string)
  default     = []
}

variable "ingress_dns_name" {
  description = "DNS name for ingress, for which record will be crated in the domain: endpoints.$${PROJECT_ID}.cloud.goog"
  default     = "ingressgateway"
  type        = string
}

variable "ingress_static_ip" {
  description = "Static IP address for ASM Ingress"
  type        = string
  default     = "10.0.17.100"
}

variable "ip_ranges" {
  description = "Subnet IP CIDR ranges."
  type = object({
    shared-vpc = string
    bastion    = string
  })
  default = {
    shared-vpc = "10.0.16.0/20"
    bastion    = "10.0.32.0/20"
  }
}

variable "ip_secondary_ranges" {
  description = "Secondary IP CIDR ranges."
  type        = map(string)
  default = {
    gke-pods     = "10.128.0.0/18"
    gke-services = "172.16.0.0/24"
  }
}

variable "net_owners" {
  description = "Host VPC project owners, in IAM format."
  type        = list(string)
  default     = []
}

variable "prefix" {
  description = "Prefix used for resource names."
  type        = string
  validation {
    condition     = var.prefix != ""
    error_message = "Prefix cannot be empty."
  }
  validation {
    condition     = length(var.prefix) < 23
    error_message = "Length of prefix needs to be less than 23 and currently equals ${length(var.prefix)}"
  }
}

variable "proxy_only_cidr" {
  description = "CIDR for proxy only subnet"
  type        = string
  default     = "10.0.64.0/20"
}

variable "region" {
  description = "Region used."
  type        = string
  default     = "europe-west2"
}

variable "root_node" {
  description = "Hierarchy node where projects will be created, 'organizations/org_id' or 'folders/folder_id'."
  type        = string
}
