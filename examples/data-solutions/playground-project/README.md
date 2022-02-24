# Data Playground environment

This example creates the infrastructure needed to run different data products in a playground environment. This example is meant to be a starting point to familiarize with a new product or to create validate a new infrastructure.

The solution will use:
- Service account to be used by your application
- VPC with a subnet to run your application (for example: Cloud Dataproc cluster or Cloud Dataflow pipeline)
- Cloud NAT to let resources egress to the Internet, to run system updates and install packages

It can be used as a starting point for more complex scenarios.

## Managed resources and services

This sample creates several distinct groups of resources:

- projects
  - Project configured for GCS buckets, Dataflow instances and BigQuery tables and orchestration
- networking
  - VPC network
  - One subnet
  - Firewall rules for [SSH access via IAP](https://cloud.google.com/iap/docs/using-tcp-forwarding) and open communication within the VPC
- IAM
  - One service account for the application
  - One service account for for the GCE instance
- GCE
  - One instance
- GCS
  - One bucket
- BQ
  - One dataset

## Deploy your enviroment

We assume the identiy running the following steps has the following role:
 - `resourcemanager.projectCreator` in case a new project will be created.
 - `owner` on the project in case you use an existing project. 

Run Terraform init:

```
$ terraform init
```

Configure the Terraform variable in your `terraform.tfvars` file. You need to spefify at least the following variables:

```
project_id      = "datalake-001"
prefix          = "prefix"
```

You can run now:

```
$ terraform apply
```

You should see the output of the Terraform script with resources created and some command pre-created for you to run the example following steps below.
<!-- BEGIN TFDOC -->

## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| [prefix](variables.tf#L20) | Unique prefix used for resource names. Not used for project if 'project_create' is null. | <code>string</code> | ✓ |  |
| [project_id](variables.tf#L34) | Project id, references existing project if `project_create` is null. | <code>string</code> | ✓ |  |
| [data_force_destroy](variables.tf#L15) | Flag to set 'force_destroy' on data services like BiguQery or Cloud Storage. | <code>bool</code> |  | <code>false</code> |
| [project_create](variables.tf#L25) | Provide values if project creation is needed, uses existing project if null. Parent is in 'folders/nnn' or 'organizations/nnn' format. | <code title="object&#40;&#123;&#10;  billing_account_id &#61; string&#10;  parent             &#61; string&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |
| [project_services](variables.tf#L39) | List of core services enabled on all projects. | <code>list&#40;string&#41;</code> |  | <code title="&#91;&#10;  &#34;bigquery.googleapis.com&#34;,&#10;  &#34;bigqueryreservation.googleapis.com&#34;,&#10;  &#34;bigquerystorage.googleapis.com&#34;,&#10;  &#34;cloudresourcemanager.googleapis.com&#34;,&#10;  &#34;compute.googleapis.com&#34;,&#10;  &#34;iam.googleapis.com&#34;,&#10;  &#34;servicenetworking.googleapis.com&#34;,&#10;  &#34;serviceusage.googleapis.com&#34;,&#10;  &#34;stackdriver.googleapis.com&#34;,&#10;  &#34;storage.googleapis.com&#34;,&#10;  &#34;storage-component.googleapis.com&#34;,&#10;&#93;">&#91;&#8230;&#93;</code> |
| [region](variables.tf#L57) | The region where resources will be deployed. | <code>string</code> |  | <code>&#34;europe-west1&#34;</code> |
| [user_principals](variables.tf#L72) | Groups with Service Account Token creator role on service accounts in IAM format, eg 'group:group@domain.com'. | <code>list&#40;string&#41;</code> |  | <code>&#91;&#93;</code> |
| [vpc_subnet_range](variables.tf#L78) | Ip range used for the VPC subnet created for the example. | <code>string</code> |  | <code>&#34;10.0.0.0&#47;20&#34;</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [buckets](outputs.tf#L15) | GCS bucket Cloud KMS crypto keys. |  |
| [project_id](outputs.tf#L20) | Project id. |  |
| [service_accounts](outputs.tf#L25) | Service account. |  |

<!-- END TFDOC -->
