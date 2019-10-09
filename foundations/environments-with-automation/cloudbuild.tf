# Copyright 2019 Google LLC
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
  app_names                 = [for app in var.applications : app["name"]]
  app_to_admins_mapping     = { for app in var.applications : app["name"] => app["admins"] }
  app_to_developers_mapping = { for app in var.applications : app["name"] => app["developers"] }
  app_to_viewers_mapping    = { for app in var.applications : app["name"] => app["viewers"] }
  app_to_env_mapping        = setproduct(local.app_names, var.environments)
  cloudbuild_triggers       = { for item in local.app_to_env_mapping : "${item[0]}-${item[1]}" => { "repository" : item[0], "branch" : item[1] } }
}

resource "google_sourcerepo_repository" "app_repository" {
  for_each = toset(local.app_names)
  name     = each.value
  project  = module.project-automation.project_id
}

resource "google_sourcerepo_repository_iam_binding" "app_admins" {
  for_each   = toset(local.app_names)
  project    = module.project-automation.project_id
  repository = google_sourcerepo_repository.app_repository[each.value].name
  role       = "roles/source.admin"
  members    = local.app_to_admins_mapping[each.value]
}

resource "google_sourcerepo_repository_iam_binding" "app_developer" {
  for_each   = toset(local.app_names)
  project    = module.project-automation.project_id
  repository = google_sourcerepo_repository.app_repository[each.value].name
  role       = "roles/source.writer"
  members    = local.app_to_developers_mapping[each.value]
}

resource "google_sourcerepo_repository_iam_binding" "app_viewers" {
  for_each   = toset(local.app_names)
  project    = module.project-automation.project_id
  repository = google_sourcerepo_repository.app_repository[each.value].name
  role       = "roles/source.reader"
  members    = local.app_to_viewers_mapping[each.value]
}

resource "google_cloudbuild_trigger" "image_build_trigger" {
  for_each    = local.cloudbuild_triggers
  description = "Trigger for repository ${each.value["repository"]}, branch ${each.value["branch"]}"
  project     = module.project-automation.project_id

  trigger_template {
    branch_name = each.value["branch"]
    repo_name   = each.value["repository"]
  }

  build {
    step {
      name = "gcr.io/$PROJECT_ID/terraform"
      args = ["init", "-backend-config=bucket=${module.gcs-tf-environments.names[each.value["branch"]]}", "-backend-config=prefix=$REPO_NAME/$BRANCH_NAME"]
    }
    step {
      name = "gcr.io/$PROJECT_ID/terraform"
      args = ["validate", "-var-file=$BRANCH_NAME.tfvars"]
      env = ["TF_VAR_environment=$BRANCH_NAME",
        "_IMPERSONATE_SA=${module.service-accounts-tf-environments.emails[each.value["branch"]]}",
      "TF_VAR_folder_id=${module.folders-top-level.ids[each.value["branch"]]}"]
    }
    step {
      name = "gcr.io/$PROJECT_ID/terraform"
      args = ["plan", "-var-file=$BRANCH_NAME.tfvars"]
      env = ["TF_VAR_environment=$BRANCH_NAME",
        "_IMPERSONATE_SA=${module.service-accounts-tf-environments.emails[each.value["branch"]]}",
      "TF_VAR_folder_id=${module.folders-top-level.ids[each.value["branch"]]}"]
    }
    step {
      name = "gcr.io/$PROJECT_ID/terraform"
      args = ["apply", "-var-file=$BRANCH_NAME.tfvars", "-auto-approve"]
      env = ["TF_VAR_environment=$BRANCH_NAME",
        "_IMPERSONATE_SA=${module.service-accounts-tf-environments.emails[each.value["branch"]]}",
      "TF_VAR_folder_id=${module.folders-top-level.ids[each.value["branch"]]}"]
    }
  }

  depends_on = [
    "google_sourcerepo_repository.app_repository",
  ]
}

