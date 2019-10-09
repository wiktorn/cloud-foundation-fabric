FROM alpine:3.10

ARG TERRAFORM_VERSION
ARG TERRAFORM_VERSION_SHA256SUM

COPY terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
RUN echo "${TERRAFORM_VERSION_SHA256SUM}  terraform_${TERRAFORM_VERSION}_linux_amd64.zip" > checksum && sha256sum -c checksum
RUN unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip

COPY jq-linux64 jq-linux64
RUN chmod +x jq-linux64

FROM gcr.io/cloud-builders/gcloud

COPY --from=0 jq-linux64 /usr/bin/jq 
COPY --from=0 terraform /usr/bin/terraform
COPY entrypoint.bash /builder/entrypoint.bash
ENTRYPOINT ["/builder/entrypoint.bash"]
