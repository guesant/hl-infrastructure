# IMPORTANT: the real value always comes from --build-arg, derived from
# ansible/group_vars/all/versions.yml, so the CI render uses the same Helm
# the Ansible roles install; this default only covers a manual build.
ARG HELM_VERSION=4.3.0

# IMPORTANT: kubectl's minor version must stay within one of k3s_version in
# ansible/group_vars/all/versions.yml, or the ops image can silently apply
# manifests the node's API server rejects; --build-arg keeps them in lockstep.
ARG KUBECTL_VERSION=v1.36.4
ARG AGE_PLUGIN_SE_VERSION=0.2.1

FROM zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f AS gitleaks

FROM ghcr.io/google/osv-scanner:v2.5.1@sha256:8108ae94eadea5a02c9bec6e646909d5b790b44bd62d7f5b7f0b1d6d0ffc7734 AS osv-scanner

FROM aquasec/trivy:0.74.0@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969 AS trivy

FROM stackrox/kube-linter:v0.8.3@sha256:f2bfce7879206d32f69ab6572c376f916643f54ca291ac38cf7d01ef591ff3f9 AS kube-linter

FROM bridgecrew/checkov:3.3.17@sha256:41c4701c6a56d8952e5aba7a420f871c8b70b57da94eb4f142dcdf7295bb0be3 AS checkov

FROM ghcr.io/yannh/kubeconform:v0.8.0@sha256:faffaf43f95aa6425306e1ab8d6fcad72acb9049158f38e574c085ea1ec0f64e AS kubeconform

FROM lycheeverse/lychee:0.24.2@sha256:e2d19e57cf6ab037026f20b8e449a1f30d9d7f81eef4194763aab2eab20bd28d AS lychee

FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck

FROM hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d AS hadolint
ENTRYPOINT ["hadolint"]

FROM ghcr.io/getsops/sops:v3.13.3-alpine@sha256:ae501277bf742f1662e0f881f43dd8fd6798b489a8058e921dbf6cda597140ea AS sops-bin

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS ops
ARG KUBECTL_VERSION
ARG AGE_PLUGIN_SE_VERSION
RUN apk add --no-cache bash age jq yq-go curl && \
    arch="$(apk --print-arch)" && \
    case "$arch" in \
    x86_64) kube_arch=amd64 ;; \
    aarch64) kube_arch=arm64 ;; \
    *) echo "unsupported arch: $arch" >&2 && exit 1 ;; \
    esac && \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${kube_arch}/kubectl" && \
    chmod 0755 /usr/local/bin/kubectl && \
    curl -fsSLo /tmp/age-plugin-se.apk "https://github.com/remko/age-plugin-se/releases/download/v${AGE_PLUGIN_SE_VERSION}/age-plugin-se-${AGE_PLUGIN_SE_VERSION}-r0-${arch}.apk" && \
    apk add --no-cache --allow-untrusted /tmp/age-plugin-se.apk && \
    rm /tmp/age-plugin-se.apk
COPY --from=sops-bin /usr/local/bin/sops /usr/local/bin/sops

FROM alpine/helm:${HELM_VERSION} AS helm

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS shell
RUN apk add --no-cache bash grep git

FROM python:3.14-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6 AS yamllint
RUN pip install --no-cache-dir yamllint==1.38.0
ENTRYPOINT ["yamllint"]

FROM python:3.14-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6 AS ansible-lint
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir ansible-lint==26.8.0
ENTRYPOINT ["ansible-lint"]

FROM node:24-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553 AS ast-grep
RUN npm install --global @ast-grep/cli@0.45.3

FROM node:24-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553 AS jscpd
RUN npm install --global jscpd@5.2.0

FROM node:24-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553 AS markdownlint
RUN npm install --global markdownlint-cli2@0.23.2

FROM node:24-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553 AS cspell
RUN mkdir -p /opt/cspell && npm install --prefix /opt/cspell cspell@10.3.0 @cspell/dict-pt-br@2.4.2
ENTRYPOINT ["/opt/cspell/node_modules/.bin/cspell"]
