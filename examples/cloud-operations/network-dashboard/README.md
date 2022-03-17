# Networking Dashboard

This repository provides an end-to-end solution to gather some GCP Networking quotas and limits (that cannot be seen in the GCP console today) and display them in a dashboard.
The goal is to allow for better visibility of these limits, facilitating capacity planning and avoiding hitting these limits.

## Usage

Clone this repository, then go through the following steps to create resources:
- Create a terraform.tfvars file with the following content:
  - organization_id = "[YOUR-ORG-ID]"
  - billing_account = "[YOUR-BILLING-ACCOUNT]"
  - monitoring_project_id = "project-0" # Monitoring project where the dashboard will be created and the solution deployed
  - monitored_projects_list = ["project-1", "project2"] # Projects to be monitored by the solution
- `terraform init`
- `terraform apply`

Once the resources are deployed, go to the following page to see the dashboard: https://console.cloud.google.com/monitoring/dashboards?project=<YOUR-MONITORING-PROJECT>.
A dashboard called "quotas-utilization" should be created.

The Cloud Function runs every 5 minutes by default so you should start getting some data points after a few minutes. 
You can change this frequency by modifying the "schedule_cron" variable in variables.tf.

Once done testing, you can clean up resources by running `terraform destroy`.

## Supported limits and quotas
The Cloud Function currently tracks usage, limit and utilization of:
- active VPC peerings per VPC
- VPC peerings per VPC
- instances per VPC
- instances per VPC peering group
- Subnet IP ranges per VPC peering group
- internal forwarding rules for internal L4 load balancers per VPC
- internal forwarding rules for internal L7 load balancers per VPC
- internal forwarding rules for internal L4 load balancers per VPC peering group
- internal forwarding rules for internal L7 load balancers per VPC peering group

It writes this values to custom metrics in Cloud Monitoring and creates a dashboard to visualize the current utilization of these metrics in Cloud Monitoring.