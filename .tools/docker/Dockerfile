
ARG KUBECTL_VERSION=v1.36.4
ARG AGE_PLUGIN_SE_VERSION=0.2.1
ARG AGE_PLUGIN_SE_SHA256_AARCH64=08b7ae6cc8e62a467dfc90e515339571b5872ca8a952b5dde5186dcad41fbad2
ARG AGE_PLUGIN_SE_SHA256_X86_64=cfb21e69a4322aa323bcf7160236e71134fcc333f4f025a6ea4729f93bc5c256

FROM zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f AS gitleaks

FROM ghcr.io/google/osv-scanner:v2.5.1@sha256:8108ae94eadea5a02c9bec6e646909d5b790b44bd62d7f5b7f0b1d6d0ffc7734 AS osv-scanner

FROM aquasec/trivy:0.74.0@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969 AS trivy

FROM stackrox/kube-linter:v0.8.3@sha256:f2bfce7879206d32f69ab6572c376f916643f54ca291ac38cf7d01ef591ff3f9 AS kube-linter

FROM bridgecrew/checkov:3.3.17@sha256:41c4701c6a56d8952e5aba7a420f871c8b70b57da94eb4f142dcdf7295bb0be3 AS checkov

FROM ghcr.io/yannh/kubeconform:v0.8.0@sha256:faffaf43f95aa6425306e1ab8d6fcad72acb9049158f38e574c085ea1ec0f64e AS kubeconform

FROM lycheeverse/lychee:0.24.2@sha256:e2d19e57cf6ab037026f20b8e449a1f30d9d7f81eef4194763aab2eab20bd28d AS lychee

FROM jdkato/vale:v3.22.0@sha256:0ef74c2c8331a2cc8739ecc8b4f7cc6672e61524c3697e8c8857bc86b724a28e AS vale

FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck

FROM hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d AS hadolint
ENTRYPOINT ["hadolint"]

FROM ghcr.io/getsops/sops:v3.13.3-alpine@sha256:ae501277bf742f1662e0f881f43dd8fd6798b489a8058e921dbf6cda597140ea AS sops-bin

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS ops
ARG KUBECTL_VERSION
ARG AGE_PLUGIN_SE_VERSION
ARG AGE_PLUGIN_SE_SHA256_AARCH64
ARG AGE_PLUGIN_SE_SHA256_X86_64
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
RUN apk add --no-cache bash age jq yq-go curl && \
    arch="$(apk --print-arch)" && \
    case "$arch" in \
    x86_64) kube_arch=amd64; apk_sha="$AGE_PLUGIN_SE_SHA256_X86_64" ;; \
    aarch64) kube_arch=arm64; apk_sha="$AGE_PLUGIN_SE_SHA256_AARCH64" ;; \
    *) echo "unsupported arch: $arch" >&2 && exit 1 ;; \
    esac && \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${kube_arch}/kubectl" && \
    curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${kube_arch}/kubectl.sha256" && \
    echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c - && \
    chmod 0755 /usr/local/bin/kubectl && \
    curl -fsSLo /tmp/age-plugin-se.apk "https://github.com/remko/age-plugin-se/releases/download/v${AGE_PLUGIN_SE_VERSION}/age-plugin-se-${AGE_PLUGIN_SE_VERSION}-r0-${arch}.apk" && \
    echo "${apk_sha}  /tmp/age-plugin-se.apk" | sha256sum -c - && \
    apk add --no-cache --allow-untrusted /tmp/age-plugin-se.apk && \
    rm /tmp/age-plugin-se.apk /tmp/kubectl.sha256
COPY --from=sops-bin /usr/local/bin/sops /usr/local/bin/sops

FROM alpine/helm:4.3.0@sha256:a6cf54599ccb99d90cf0712b30f03fdb3cab062e6b94e0418cc4db7e8a1464b2 AS helm

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS shell
RUN apk add --no-cache bash grep git

FROM python:3.14-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6 AS yamllint
COPY pip/yamllint.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt
ENTRYPOINT ["yamllint"]

FROM python:3.14-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6 AS ansible-lint
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/* \
    && true
COPY pip/ansible-lint.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt
ENTRYPOINT ["ansible-lint"]

FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS ast-grep
COPY npm/ast-grep/package.json npm/ast-grep/package-lock.json /opt/ast-grep/
RUN npm ci --prefix /opt/ast-grep --ignore-scripts --no-audit --no-fund && ln -s /opt/ast-grep/node_modules/.bin/ast-grep /usr/local/bin/ast-grep && ln -s /opt/ast-grep/node_modules/.bin/sg /usr/local/bin/sg

FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS jscpd
COPY npm/jscpd/package.json npm/jscpd/package-lock.json /opt/jscpd/
RUN npm ci --prefix /opt/jscpd --ignore-scripts --no-audit --no-fund && ln -s /opt/jscpd/node_modules/.bin/jscpd /usr/local/bin/jscpd

FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS markdownlint
COPY npm/markdownlint/package.json npm/markdownlint/package-lock.json /opt/markdownlint/
RUN npm ci --prefix /opt/markdownlint --ignore-scripts --no-audit --no-fund && ln -s /opt/markdownlint/node_modules/.bin/markdownlint-cli2 /usr/local/bin/markdownlint-cli2

FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS cspell
COPY npm/cspell/package.json npm/cspell/package-lock.json /opt/cspell/
RUN npm ci --prefix /opt/cspell --ignore-scripts --no-audit --no-fund
ENTRYPOINT ["/opt/cspell/node_modules/.bin/cspell"]

FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS commitlint
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/* \
    && true
COPY npm/commitlint/package.json npm/commitlint/package-lock.json /opt/commitlint/
RUN npm ci --prefix /opt/commitlint --ignore-scripts --no-audit --no-fund
ENV NODE_PATH=/opt/commitlint/node_modules
ENTRYPOINT ["/opt/commitlint/node_modules/.bin/commitlint"]

FROM quay.io/kubescape/kubescape-cli:v4.0.13@sha256:cf9b0dc386e75e8dea9ad443f9497fe73e0251476bbea5efe51a0d368d7a7d12 AS kubescape

FROM openpolicyagent/conftest:v0.69.0@sha256:a38ba21668929a00dce2fe6ee43d1312228340bce5fd243f47dd0ce90516e558 AS conftest
