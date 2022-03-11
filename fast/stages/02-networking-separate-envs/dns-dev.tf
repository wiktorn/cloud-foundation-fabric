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

# tfdoc:file:description Development spoke DNS zones and peerings setup.

# GCP-specific environment zone

module "dev-dns-private-zone" {
  source          = "../../../modules/dns"
  project_id      = module.dev-project.project_id
  type            = "private"
  name            = "dev-gcp-example-com"
  domain          = "dev.gcp.example.com."
  client_networks = [module.dev-vpc.self_link]
  recordsets = {
    "A localhost" = { type = "A", ttl = 300, records = ["127.0.0.1"] }
  }
}

module "dev-onprem-example-dns-forwarding" {
  source          = "../../../modules/dns"
  project_id      = module.dev-project.project_id
  type            = "forwarding"
  name            = "example-com"
  domain          = "onprem.example.com."
  client_networks = [module.dev-vpc.self_link]
  forwarders      = { for ip in var.dns.onprem : ip => null }
}

module "dev-reverse-10-dns-forwarding" {
  source          = "../../../modules/dns"
  project_id      = module.dev-project.project_id
  type            = "forwarding"
  name            = "root-reverse-10"
  domain          = "10.in-addr.arpa."
  client_networks = [module.dev-vpc.self_link]
  forwarders      = { for ip in var.dns.onprem : ip => null }
}