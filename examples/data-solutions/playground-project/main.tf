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

locals {
  iam = {
    # Add here roles for the Service Account
  }
  group_iam = {

  }
}

module "project" {
  source          = "../../../modules/project"
  name            = var.project_id
  parent          = try(var.project_create.parent, null)
  billing_account = try(var.project_create.billing_account_id, null)
  project_create  = var.project_create != null
  prefix          = var.project_create == null ? null : var.prefix
  services        = var.project_services

  # additive IAM bindings avoid disrupting bindings in existing project
  iam          = var.project_create != null ? local.iam : {}
  iam_additive = var.project_create == null ? local.iam : {}
  service_config = {
    disable_on_destroy = false, disable_dependent_services = false
  }
}

# VPC

module "vpc" {
  source     = "../../../modules/net-vpc"
  project_id = module.project.project_id
  name       = "${var.prefix}-vpc"
  subnets = [
    {
      ip_cidr_range      = var.vpc_subnet_range
      name               = "subnet"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
}

module "vpc-firewall" {
  source       = "../../../modules/net-vpc-firewall"
  project_id   = module.project.project_id
  network      = module.vpc.name
  admin_ranges = [var.vpc_subnet_range]
}

module "nat" {
  source         = "../../../modules/net-cloudnat"
  project_id     = module.project.project_id
  region         = var.region
  name           = "${var.prefix}-default"
  router_network = module.vpc.name
}

# Cloud GCS bucket

module "gcs-bucket" {
  source         = "../../../modules/gcs"
  project_id     = module.project.project_id
  prefix         = var.prefix
  name           = "bucket"
  location       = var.region
  storage_class  = "REGIONAL"
  encryption_key = try(var.service_encryption_keys.storage, null)
  force_destroy  = var.data_force_destroy
}

# BigQuery

module "bigquery-dataset" {
  source     = "../../../modules/bigquery-dataset"
  project_id = module.project.project_id
  id         = "dataset"
  location   = var.region
  options = {
    default_table_expiration_ms     = null
    default_partition_expiration_ms = null
    delete_contents_on_destroy      = var.data_force_destroy
  }
  encryption_key = try(var.service_encryption_keys.bq, null)
}

# Service Account

module "service-account" {
  source     = "../../../modules/iam-service-account"
  project_id = module.project.project_id
  name       = "service"
}

# GCE

module "service-account-gce" {
  source     = "../../../modules/iam-service-account"
  project_id = module.project.project_id
  name       = "gce-test"
  iam_project_roles = {
    (module.project.project_id) = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
    ]
  }
}

module "vm-test" {
  source     = "../../../modules/compute-vm"
  project_id = module.project.project_id
  zone       = "${var.region}-b"
  name       = "test-0"
  network_interfaces = [{
    network    = module.vpc.self_link
    subnetwork = module.vpc.subnet_self_links["${var.region}/subnet"]
    nat        = false
    addresses  = null
  }]
  service_account        = module.service-account-gce.email
  service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  tags                   = ["ssh"]
  encryption = {
    encrypt_boot            = can(var.service_encryption_keys.compute) ? true : false
    disk_encryption_key_raw = null
    kms_key_self_link       = try(var.service_encryption_keys.compute, null)
  }
}
