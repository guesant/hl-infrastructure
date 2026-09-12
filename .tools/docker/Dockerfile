# IMPORTANT: the real value always comes from --build-arg, derived from
# ansible/group_vars/all/versions.yml, so the CI render uses the same Helm
# the Ansible roles install; this default only covers a manual build.
ARG HELM_VERSION=4.2.4

FROM zricethezav/gitleaks:v8.30.1 AS gitleaks

FROM ghcr.io/google/osv-scanner:v2.5.1 AS osv-scanner

FROM aquasec/trivy:0.74.0 AS trivy

FROM stackrox/kube-linter:v0.8.3 AS kube-linter

FROM bridgecrew/checkov:3.3.17 AS checkov

FROM ghcr.io/yannh/kubeconform:v0.8.0 AS kubeconform

FROM alpine/helm:${HELM_VERSION} AS helm

FROM node:20-slim AS ast-grep
RUN npm install --global @ast-grep/cli@0.45.3

FROM node:20-slim AS jscpd
RUN npm install --global jscpd@5.2.0
