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

resource "null_resource" "build_and_push_tf_image" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cloudbuild_yaml_sha1 = sha1(file("${path.module}/cloudbuild.yaml"))
    dockerfile_sha1      = sha1(file("${path.module}/Dockerfile"))
    entrypoint_bash_sha1 = sha1(file("${path.module}/entrypoint.bash"))
  }

  provisioner "local-exec" {
    command = "cd ${path.module} && gcloud config set project ${var.project_id}; gcloud builds submit . --config cloudbuild.yaml"
  }
}

resource "null_resource" "remove_tf_image" {
  provisioner "local-exec" {
    when    = "destroy"
    command = "gcloud config set project ${var.project_id}; gcloud container images delete terraform --force-delete-tags --quiet"
  }
}