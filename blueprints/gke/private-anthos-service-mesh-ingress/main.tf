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

###############################################################################
#                          Host and service projects                          #
###############################################################################

# the container.hostServiceAgentUser role is needed for GKE on shared VPC
# see: https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-shared-vpc#grant_host_service_agent_role

module "project-host" {
  source          = "../../../modules/project"
  parent          = var.root_node
  billing_account = var.billing_account_id
  prefix          = var.prefix
  name            = "net"
  services = [
    "dns.googleapis.com",
    "container.googleapis.com"
  ]
  shared_vpc_host_config = {
    enabled = true
  }
  iam = {
    "roles/owner" = var.net_owners
  }
}

# the container.developer role assigned to the bastion instance service account
# allows to fetch GKE credentials from bastion for clusters in this project

module "project-svc-gke" {
  source          = "../../../modules/project"
  parent          = var.root_node
  billing_account = var.billing_account_id
  prefix          = var.prefix
  name            = "gke"
  services = [
    "container.googleapis.com",
    "stackdriver.googleapis.com",
    "mesh.googleapis.com",
    "meshconfig.googleapis.com",
    "iap.googleapis.com",
    "anthos.googleapis.com",
    "gkehub.googleapis.com",
    "cloudtrace.googleapis.com"
  ]
  shared_vpc_service_config = {
    host_project = module.project-host.project_id
    service_identity_iam = {
      "roles/container.hostServiceAgentUser" = ["container-engine"]
      "roles/compute.networkUser"            = ["container-engine"]
    }
  }
  iam = {
    "roles/container.developer"     = [module.vm-bastion.service_account_iam_email]
    "roles/owner"                   = var.gke_owners,
    "roles/logging.logWriter"       = [module.cluster-1-nodepool-1.service_account_iam_email]
    "roles/monitoring.metricWriter" = [module.cluster-1-nodepool-1.service_account_iam_email]
    "roles/container.admin"         = var.admin_user
    "roles/gkehub.admin"            = var.admin_user
    "roles/gkehub.serviceAgent"     = ["serviceAccount:${module.project-svc-gke.service_accounts.robots.fleet}"]
  }
}

module "project-bastion" {
  source          = "../../../modules/project"
  parent          = var.root_node
  billing_account = var.billing_account_id
  prefix          = var.prefix
  name            = "bastion"
  services = [
    "iap.googleapis.com" # needed for oslogin to work
  ]
  oslogin        = true
  oslogin_admins = var.bastion_owners

  shared_vpc_service_config = {
    host_project = module.project-host.project_id
    service_identity_iam = {
      "roles/compute.networkUser" = ["cloudservices"]
    }
  }
  iam = {
    "roles/owner" = var.bastion_owners
  }
}


################################################################################
#                                  Networking                                  #
################################################################################

# subnet IAM bindings control which identities can use the individual subnets

module "vpc-shared" {
  source     = "../../../modules/net-vpc"
  project_id = module.project-host.project_id
  name       = "shared-vpc"
  subnets = [
    {
      ip_cidr_range = var.ip_ranges.shared-vpc
      name          = "gke"
      region        = var.region
      secondary_ip_ranges = {
        pods     = var.ip_secondary_ranges.gke-pods
        services = var.ip_secondary_ranges.gke-services
      }
    }
  ]
  subnets_proxy_only = [{
    name          = "proxy-only"
    ip_cidr_range = var.proxy_only_cidr
    region        = var.region
    description   = "Proxy-only subnet for ILB for ASM Ingress Gateway"
    active        = true
  }]
  subnet_iam = {
    "${var.region}/gke" = {
      "roles/compute.networkUser" = concat(var.gke_owners, [
        "serviceAccount:${module.project-svc-gke.service_accounts.cloud_services}",
        "serviceAccount:${module.project-svc-gke.service_accounts.robots.container-engine}",
      ])
      "roles/compute.securityAdmin" = [
        "serviceAccount:${module.project-svc-gke.service_accounts.robots.container-engine}",
      ]
    }
  }
}

module "vpc-bastion" {
  source     = "../../../modules/net-vpc"
  project_id = module.project-bastion.project_id
  name       = "bastion-vpc"
  subnets = [
    {
      ip_cidr_range = var.ip_ranges.bastion
      name          = "bastion"
      region        = var.region
    }
  ]
}

module "vpc-shared-firewall" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.project-host.project_id
  network    = module.vpc-shared.name

  default_rules_config = {
    disabled = true
  }
  ingress_rules = {
    ssh = {
      description          = "Allow SSH from bastion (service accounts)"
      source_ranges        = ["${module.vm-bastion.internal_ip}/32"]
      enable_logging       = { include_metadata = true }
      use_service_accounts = true
      targets = [
        module.cluster-1-nodepool-1.service_account_email,
      ]
      rules = [
        {
          ports    = ["22"]
          protocol = "tcp"
        }
      ]
    }
    allow-proxy-connection = {
      description          = "Allow connections from proxy-only network"
      source_ranges        = [var.proxy_only_cidr]
      enable_logging       = { include_metadata = true }
      use_service_accounts = false
      rules = [
        {
          ports    = ["80", "443", "15021"]
          protocol = "tcp"
        }
      ]
    }
    allow-health-checks = {
      description          = "Allow healthchecks"
      source_ranges        = ["health-checkers"]
      enable_logging       = { include_metadata = true }
      use_service_accounts = true
      targets = [
        module.cluster-1-nodepool-1.service_account_email,
      ]
      rules = [
        {
          ports    = []
          protocol = "all"
        }
      ]
    }
    log-deny = {
      description          = "Deny-log all"
      source_ranges        = ["0.0.0.0/0"]
      enable_logging       = { include_metadata = true }
      use_service_accounts = false
      priority             = 65534
      deny                 = true
      rules = [
        {
          ports    = []
          protocol = "all"
        }
      ]
    }
  }
}

module "host-to-bastion-vpn-r1" {
  source     = "../../../modules/net-vpn-ha"
  project_id = module.project-host.project_id
  network    = module.vpc-shared.self_link
  region     = var.region
  name       = "${var.prefix}-host-to-bastion-r1"
  router_config = {
    name = "${var.prefix}-host-vpn-r1"
    asn  = "64514"
    #    custom_advertise = {
    #      all_subnets = true
    #      # ip_ranges   = coalesce(var.vpn_configs.land-r1.custom_ranges, {})
    #      mode        = "DEFAULT"
    #    }
  }
  peer_gateway = { gcp = module.bastion-to-host-vpn-r1.self_link }
  tunnels = {
    0 = {
      bgp_peer = {
        address = "169.254.2.2"
        asn     = module.bastion-to-host-vpn-r1.router.bgp[0].asn
      }
      bgp_session_range     = "169.254.2.1/30"
      vpn_gateway_interface = 0
    }
    1 = {
      bgp_peer = {
        address = "169.254.2.6"
        asn     = module.bastion-to-host-vpn-r1.router.bgp[0].asn
      }
      bgp_session_range     = "169.254.2.5/30"
      vpn_gateway_interface = 1
    }
  }
}

module "bastion-to-host-vpn-r1" {
  source     = "../../../modules/net-vpn-ha"
  project_id = module.project-bastion.project_id
  network    = module.vpc-bastion.self_link
  region     = var.region
  name       = "${var.prefix}-bastion-to-host-r1"
  router_config = {
    name = "${var.prefix}-bastion-vpn-r1"
    asn  = 64515
    #    custom_advertise = {
    #      all_subnets = true
    #      ip_ranges   = {} # module.vpc-bastion.subnet_ips
    #    }
  }
  peer_gateway = { gcp = module.host-to-bastion-vpn-r1.self_link }
  tunnels = {
    0 = {
      bgp_peer = {
        address = "169.254.2.1"
        asn     = module.host-to-bastion-vpn-r1.router.bgp[0].asn
      }
      bgp_session_range     = "169.254.2.2/30"
      shared_secret         = module.host-to-bastion-vpn-r1.random_secret
      vpn_gateway_interface = 0
    }
    1 = {
      bgp_peer = {
        address = "169.254.2.5"
        asn     = module.host-to-bastion-vpn-r1.router.bgp[0].asn
      }
      bgp_session_range     = "169.254.2.6/30"
      shared_secret         = module.host-to-bastion-vpn-r1.random_secret
      vpn_gateway_interface = 1
    }
  }
}



module "nat" {
  source        = "../../../modules/net-cloudnat"
  project_id    = module.project-bastion.project_id
  region        = var.region
  name          = "vpc-shared"
  router_create = false
  router_name   = module.bastion-to-host-vpn-r1.router_name
}

################################################################################
#                                     VM                                      #
################################################################################

module "vm-bastion" {
  source     = "../../../modules/compute-vm"
  project_id = module.project-bastion.project_id
  zone       = "${var.region}-b"
  name       = "bastion"
  network_interfaces = [{
    network    = module.vpc-bastion.self_link
    subnetwork = lookup(module.vpc-bastion.subnet_self_links, "${var.region}/bastion", null)
    nat        = false
    addresses  = null
  }]
  tags                   = ["ssh"]
  boot_disk              = { type = "pd-ssd" }
  instance_type          = "n1-standard-1"
  options                = { spot = true }
  service_account_create = true
}

################################################################################
#                                     GKE                                      #
################################################################################

module "cluster-1" {
  source     = "../../../modules/gke-cluster"
  name       = "cluster"
  project_id = module.project-svc-gke.project_id
  location   = "${var.region}-b"
  vpc_config = {
    network    = module.vpc-shared.self_link
    subnetwork = module.vpc-shared.subnet_self_links["${var.region}/gke"]
    master_authorized_ranges = merge(var.gke_authorized_ranges, {
      internal-vms = var.ip_ranges.bastion
    })
    master_ipv4_cidr_block = var.gke_master_network_ranges.cluster
    secondary_range_names = {
      pods     = "pods"
      services = "services"
    }
  }
  max_pods_per_node = 32
  private_cluster_config = {
    enable_private_endpoint = false
    master_global_access    = true
  }
  labels = {
    environment = "test"
    mesh_id     = "proj-${module.project-svc-gke.number}"
  }
  enable_features = {
    workload_identity = true
    dataplane_v2      = true
  }
}

module "cluster-1-nodepool-1" {
  source       = "../../../modules/gke-nodepool"
  name         = "nodepool-1"
  project_id   = module.project-svc-gke.project_id
  location     = module.cluster-1.location
  cluster_name = module.cluster-1.name
  cluster_id   = module.cluster-1.id
  service_account = {
    create = true
  }
  nodepool_config = {
    autoscaling = {
      location_policy = "ANY"
      min_node_count  = 1
      max_node_count  = 4
    }
  }
  node_config = {
    disk_type    = "pd-ssd"
    machine_type = "e2-standard-2"
    spot         = true
  }
}

################################################################################
#                                   Anthos                                     #
################################################################################

resource "google_gke_hub_membership" "membership" {
  project = module.project-svc-gke.project_id
  # use cluster-1.id to force replacement if cluster is recreated (and google_gke_hub_feature_membership as well)
  membership_id = "${module.project-svc-gke.project_id}-${reverse(split("/", module.cluster-1.id))[0]}"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${module.cluster-1.cluster.id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${module.cluster-1.cluster.id}"
  }
  provider = google-beta
}

resource "google_gke_hub_feature" "feature" {
  name     = "servicemesh"
  location = "global"
  project  = module.project-svc-gke.project_id

  provider = google-beta
}

resource "google_gke_hub_feature_membership" "feature_member" {
  location   = "global"
  project    = module.project-svc-gke.project_id
  feature    = google_gke_hub_feature.feature.name
  membership = google_gke_hub_membership.membership.membership_id
  mesh {
    management    = "MANAGEMENT_AUTOMATIC"
    control_plane = "AUTOMATIC"
  }
  provider = google-beta
}

################################################################################
#                            Anthos Ingress                                    #
################################################################################

locals {
  ingress_service_name = "${var.ingress_dns_name}.endpoints.${module.project-svc-gke.project_id}.cloud.goog"
}

resource "google_compute_address" "ingress_static_ip" {
  project      = module.project-svc-gke.project_id
  name         = "static-ingress-ip"
  subnetwork   = module.vpc-shared.subnets["${var.region}/gke"].id
  address_type = "INTERNAL"
  address      = var.ingress_static_ip
  region       = var.region
}

resource "google_endpoints_service" "ingress_endpoint" {
  project        = module.project-svc-gke.project_id
  service_name   = local.ingress_service_name
  openapi_config = <<EOL
swagger: "2.0"
info:
  description: "Cloud Endpoints DNS"
  title: "Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "${local.ingress_service_name}"
x-google-endpoints:
- name: "${local.ingress_service_name}"
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
    common_name  = local.ingress_service_name
    organization = "Example"
  }
  validity_period_hours = 30 * 24
  allowed_uses          = ["server_auth"]
}

resource "local_sensitive_file" "kubectl_ssl_secret" {
  filename = "ssl-secret.yaml"
  content  = <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: lb-tls-certificate
data:
  tls.crt: ${base64encode(tls_self_signed_cert.loadbalancer.cert_pem)}
  tls.key: ${base64encode(tls_private_key.loadbalancer.private_key_pem)}
EOF
}