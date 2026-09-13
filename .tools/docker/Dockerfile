# IMPORTANT: the real value always comes from --build-arg, derived from
# ansible/group_vars/all/versions.yml, so the CI render uses the same Helm
# the Ansible roles install; this default only covers a manual build.
ARG HELM_VERSION=4.3.0

FROM zricethezav/gitleaks:v8.30.1 AS gitleaks

FROM ghcr.io/google/osv-scanner:v2.5.1 AS osv-scanner

FROM aquasec/trivy:0.74.0 AS trivy

FROM stackrox/kube-linter:v0.8.3 AS kube-linter

FROM bridgecrew/checkov:3.3.17 AS checkov

FROM ghcr.io/yannh/kubeconform:v0.8.0 AS kubeconform

FROM lycheeverse/lychee:0.24.2 AS lychee

FROM alpine/helm:${HELM_VERSION} AS helm

FROM alpine:3.24 AS shell
RUN apk add --no-cache bash grep git

FROM python:3.14-slim AS yamllint
RUN pip install --no-cache-dir yamllint==1.38.0
ENTRYPOINT ["yamllint"]

FROM python:3.14-slim AS ansible-lint
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir ansible-lint==26.8.0
ENTRYPOINT ["ansible-lint"]

FROM node:24-slim AS ast-grep
RUN npm install --global @ast-grep/cli@0.45.3

FROM node:24-slim AS jscpd
RUN npm install --global jscpd@5.2.0

FROM node:24-slim AS cspell
RUN mkdir -p /opt/cspell && npm install --prefix /opt/cspell cspell@10.3.0 @cspell/dict-pt-br@2.4.2
ENTRYPOINT ["/opt/cspell/node_modules/.bin/cspell"]
