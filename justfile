set shell := ["bash", "-uc"]

kubeconfig := "ansible/kubeconfig"
actionlint_image := `grep -oE "rhysd/actionlint:[0-9.]+" .github/workflows/ci.yml | head -1`
zizmor_version := `grep -oE 'version: "[0-9.]+"' .github/workflows/ci.yml | grep -oE "[0-9.]+" | head -1`
helm_version := `grep -oE 'helm_version:\s*v[0-9.]+' ansible/group_vars/all/versions.yml | grep -oE "[0-9.]+"`
k3s_version := `grep -oE 'k3s_version:\s*v[0-9.]+' ansible/group_vars/all/versions.yml | grep -oE "v[0-9.]+"`
opentofu_version := "1.12.6"
tools_hash := `shasum -a 256 .tools/docker/Dockerfile | cut -c1-12`
helm_image := "hl-infra/helm:" + tools_hash + "-" + helm_version
ops_image := "hl-infra/ops:" + tools_hash + "-" + k3s_version
crd_schema_location := 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
run := "docker run --rm -v " + quote(justfile_directory()) + ":/repo -w /repo"

[doc("List every recipe")]
default:
    @just --list

[doc("Check access to the node and the assumptions the roles make (pass -K if sudo asks a password)")]
preflight *args:
    ansible-playbook -i ansible/inventory.ini ansible/preflight.yml {{args}}

[doc("Dry-run the whole bootstrap with --check --diff, applying charts as server dry-runs")]
bootstrap-check *args: (preflight args)
    ansible-galaxy collection install -r ansible/requirements.yml
    ansible-playbook -i ansible/inventory.ini ansible/site.yml --check --diff {{args}}

[doc("Run the whole Ansible bootstrap against the inventory")]
[confirm("This applies every role to the node in ansible/inventory.ini. Continue?")]
bootstrap *args: (preflight args)
    ansible-galaxy collection install -r ansible/requirements.yml
    ansible-playbook -i ansible/inventory.ini ansible/site.yml {{args}}

[doc("Rotate every k3s certificate and refresh the local kubeconfig")]
[confirm("This stops k3s for a few seconds and invalidates the current kubeconfig. Continue?")]
rotate-certs *args:
    ansible-playbook -i ansible/inventory.ini ansible/rotate-certs.yml {{args}}

[doc("Rotate the k3s node join token and restart k3s")]
[confirm("This restarts k3s. Continue?")]
rotate-token *args:
    ansible-playbook -i ansible/inventory.ini ansible/rotate-token.yml {{args}}

[doc("Print the KUBECONFIG export for the fetched kubeconfig")]
kubeconfig:
    echo "export KUBECONFIG={{justfile_directory()}}/{{kubeconfig}}"

[doc("Show nodes and ArgoCD applications")]
status:
    kubectl --kubeconfig {{kubeconfig}} get nodes
    kubectl --kubeconfig {{kubeconfig}} -n argocd get applications

[doc("actionlint and zizmor over the GitHub Actions workflows")]
lint-actions:
    test -n "{{actionlint_image}}" || (echo "could not extract the actionlint image from ci.yml" >&2 && exit 1)
    test -n "{{zizmor_version}}" || (echo "could not extract the zizmor version from ci.yml" >&2 && exit 1)
    {{run}} --entrypoint sh {{actionlint_image}} -c "actionlint -color .github/workflows/*.yml"
    {{run}} ghcr.io/zizmorcore/zizmor:{{zizmor_version}} --no-progress --config .github/zizmor.yml /repo/.github/workflows /repo/.github/actions

_build target:
    docker image inspect hl-infra/{{target}}:{{tools_hash}} >/dev/null 2>&1 || \
        docker build --target {{target}} -t hl-infra/{{target}}:{{tools_hash}} {{justfile_directory()}}/.tools/docker

_build-helm:
    test -n "{{helm_version}}" || (echo "could not extract helm_version from ansible/group_vars/all/versions.yml" >&2 && exit 1)
    docker image inspect {{helm_image}} >/dev/null 2>&1 || \
        docker build --target helm --build-arg HELM_VERSION={{helm_version}} -t {{helm_image}} {{justfile_directory()}}/.tools/docker

_build-ops:
    test -n "{{k3s_version}}" || (echo "could not extract k3s_version from ansible/group_vars/all/versions.yml" >&2 && exit 1)
    docker image inspect {{ops_image}} >/dev/null 2>&1 || \
        docker build --target ops --build-arg KUBECTL_VERSION={{k3s_version}} -t {{ops_image}} {{justfile_directory()}}/.tools/docker

[doc("yamllint over every YAML in the repository")]
lint-yaml: (_build "yamllint")
    {{run}} hl-infra/yamllint:{{tools_hash}} -c .config/yamllint.yml .

[doc("ansible-lint over the playbook and roles")]
lint-ansible: (_build "ansible-lint")
    {{run}} -e ANSIBLE_COLLECTIONS_PATH=/tmp/collections --entrypoint sh hl-infra/ansible-lint:{{tools_hash}} \
        -c "ansible-galaxy collection install -r ansible/requirements.yml -p /tmp/collections >/dev/null && ansible-lint -c .config/ansible-lint.yml"

[doc("ShellCheck over every shell script in .tools/")]
lint-shellcheck: (_build "shellcheck")
    {{run}} hl-infra/shellcheck:{{tools_hash}} .tools/*.sh

[doc("Hadolint over the tool Dockerfile")]
lint-hadolint: (_build "hadolint")
    {{run}} hl-infra/hadolint:{{tools_hash}} --ignore DL3008 --ignore DL3018 .tools/docker/Dockerfile

[doc("markdownlint-cli2 over every Markdown file")]
lint-markdown: (_build "markdownlint")
    {{run}} hl-infra/markdownlint:{{tools_hash}} markdownlint-cli2 --config .config/.markdownlint-cli2.jsonc README.md SECURITY.md SUPPORT.md CONTRIBUTING.md 'docs/**/*.md'

[doc("Fail on em dash, en dash or Unicode arrow in the prose")]
lint-prose: (_build "shell")
    {{run}} --entrypoint bash hl-infra/shell:{{tools_hash}} .tools/check-prose.sh

[doc("Fail when a page's sources changed after the page was last reviewed, or a role has no doc")]
lint-docs: (_build "shell")
    {{run}} -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/repo \
        --entrypoint bash hl-infra/shell:{{tools_hash}} .tools/check-doc-drift.sh
    {{run}} --entrypoint bash hl-infra/shell:{{tools_hash}} .tools/check-roles-documented.sh

[doc("Generate a new DR age keypair; the private half goes only into Bitwarden, never to disk")]
age-keygen: (_build-ops)
    {{run}} --entrypoint age-keygen {{ops_image}}

[doc("Manage .sops.yaml recipients: list, sync-node, add <label> <key>, update <label> <key>, remove <label>")]
sops-recipients *args: (_build-ops)
    {{run}} --entrypoint bash {{ops_image}} .tools/sops-recipients.sh {{args}}

[doc("Fail if any *-sopssecret.yaml is unencrypted or its recipients don't match .sops.yaml")]
security-sopssecrets: (_build-ops)
    {{run}} --entrypoint bash {{ops_image}} .tools/check-sopssecrets-encrypted.sh

_require-host-sops:
    command -v sops >/dev/null 2>&1 || (echo "sops not found in PATH; run: brew install sops age age-plugin-se" >&2 && exit 1)
    command -v age-plugin-se >/dev/null 2>&1 || (echo "age-plugin-se not found in PATH; run: brew install sops age age-plugin-se" >&2 && exit 1)

[doc("Generate the operator's Secure Enclave identity on this Mac; pass --force to replace it")]
age-se-keygen *args: _require-host-sops
    .tools/age-se-keygen.sh {{args}}

[doc("Open a *-sopssecret.yaml for editing with the operator Secure Enclave identity")]
sops-edit file identity=(home_dir() / ".config/hl-infrastructure/sops/operator-se.txt"): _require-host-sops
    SOPS_AGE_KEY_FILE={{identity}} sops {{file}}

[doc("Encrypt any plaintext SopsSecret and re-key any already-encrypted one; pass a file to target just it")]
sops-sync *args: _require-host-sops
    .tools/sops-sync.sh {{args}}

[doc("Rotate the data encryption key of every SopsSecret, or just one; recipients stay the same")]
sops-rotate *args: _require-host-sops
    .tools/sops-rotate.sh {{args}}

[doc("Decrypt every SopsSecret with a given identity and report OK/FAIL, no plaintext printed")]
sops-drill-dr key_file: (_build-ops)
    {{run}} -v {{quote(key_file)}}:/tmp/dr-key.txt:ro -e SOPS_AGE_KEY_FILE=/tmp/dr-key.txt --entrypoint bash {{ops_image}} .tools/sops-drill.sh

[doc("Decrypt every SopsSecret with the operator Secure Enclave identity and report OK/FAIL")]
sops-drill-se identity=(home_dir() / ".config/hl-infrastructure/sops/operator-se.txt"): _require-host-sops
    SOPS_AGE_KEY_FILE={{identity}} .tools/sops-drill.sh

[doc("Print a live resource as a clean manifest ready to commit: just freeze deployment blog -n blog")]
freeze *args: (_build-ops)
    {{run}} -e KUBECONFIG={{kubeconfig}} --entrypoint bash {{ops_image}} .tools/freeze-manifest.sh {{args}}

[doc("Run OpenTofu via Docker; no root module exists yet, this only wires the binary")]
tofu *args:
    {{run}} --entrypoint bash ghcr.io/opentofu/opentofu:{{opentofu_version}} .tools/tofu.sh {{args}}

[doc("Check every link in the Markdown files; not part of check or CI because external hosts are flaky")]
lint-links: (_build "lychee")
    {{run}} hl-infra/lychee:{{tools_hash}} --config .config/lychee.toml README.md SECURITY.md SUPPORT.md CONTRIBUTING.md 'docs/**/*.md'

[doc("Spell-check the prose in Portuguese and English")]
lint-spelling: (_build "cspell")
    {{run}} hl-infra/cspell:{{tools_hash}} --config .config/cspell.yaml --no-progress

[doc("gitleaks over the whole git history")]
security-gitleaks: (_build "gitleaks")
    {{run}} hl-infra/gitleaks:{{tools_hash}} \
        detect --source /repo --config /repo/.config/gitleaks.toml \
        --gitleaks-ignore-path /repo/.config/gitleaksignore --redact -v

[doc("osv-scanner over every dependency manifest")]
security-osv-scanner: (_build "osv-scanner")
    {{run}} hl-infra/osv-scanner:{{tools_hash}} \
        scan source --recursive --experimental-exclude rendered --allow-no-lockfiles /repo

[doc("trivy filesystem scan for vulnerabilities and secrets")]
security-trivy-fs: (_build "trivy")
    {{run}} hl-infra/trivy:{{tools_hash}} fs --scanners vuln,secret --skip-dirs rendered /repo

[doc("ast-grep structural rules from .config/ast-grep")]
quality-ast-grep: (_build "ast-grep")
    {{run}} hl-infra/ast-grep:{{tools_hash}} ast-grep scan --config .config/ast-grep/sgconfig.yml .

[doc("jscpd duplication report, informational only")]
quality-jscpd: (_build "jscpd")
    {{run}} hl-infra/jscpd:{{tools_hash}} jscpd --config .config/jscpd.json

[doc("Render the seven Helm charts into rendered/")]
infra-render-charts: _build-helm
    {{run}} --entrypoint bash {{helm_image}} .tools/render-charts.sh

[doc("helm lint over every local wrapper chart in argocd/apps")]
infra-helm-lint: _build-helm
    {{run}} --entrypoint bash {{helm_image}} .tools/lint-charts.sh

[doc("kube-linter over the rendered charts and argocd/")]
infra-kube-linter: infra-render-charts (_build "kube-linter")
    {{run}} hl-infra/kube-linter:{{tools_hash}} \
        lint --config .config/kube-linter.yaml --ignore-paths rendered/cilium.yaml rendered argocd/root argocd/applications

[doc("checkov over the rendered charts and argocd/")]
infra-checkov: infra-render-charts (_build "checkov")
    {{run}} hl-infra/checkov:{{tools_hash}} \
        --directory rendered --directory argocd/root --directory argocd/applications --framework kubernetes \
        --check CKV_K8S_16,CKV_K8S_18,CKV_K8S_19 --skip-path rendered/cilium.yaml --compact

[doc("kubeconform schema validation plus the pinned-image check")]
infra-kubeconform: infra-render-charts (_build "kubeconform") (_build "shell")
    mkdir -p {{justfile_directory()}}/.kubeconform-cache
    {{run}} hl-infra/kubeconform:{{tools_hash}} \
        -strict -ignore-missing-schemas -summary -n 2 -cache .kubeconform-cache \
        -schema-location default -schema-location '{{crd_schema_location}}' \
        -skip ImageUpdater \
        rendered argocd/root argocd/applications
    {{run}} --entrypoint bash hl-infra/shell:{{tools_hash}} .tools/check-images-pinned.sh

[doc("trivy misconfiguration scan over the rendered charts")]
infra-trivy-config: infra-render-charts (_build "trivy")
    {{run}} hl-infra/trivy:{{tools_hash}} config --misconfig-scanners kubernetes --skip-files rendered/cilium.yaml .

[doc("Build the MkDocs site in strict mode")]
docs-build:
    {{run}} python:3.12-slim \
        sh -c "pip install --quiet -r docs/requirements.txt && mkdocs build --strict --config-file .config/mkdocs.yml"

[doc("Serve the MkDocs site on port 8000")]
docs-serve:
    {{run}} -p 8000:8000 python:3.12-slim \
        sh -c "pip install --quiet -r docs/requirements.txt && mkdocs serve --dev-addr 0.0.0.0:8000 --config-file .config/mkdocs.yml"

[doc("Every check the CI runs, in order")]
check: lint-actions lint-yaml lint-ansible lint-shellcheck lint-hadolint lint-markdown lint-prose lint-docs lint-spelling security-gitleaks security-osv-scanner security-trivy-fs security-sopssecrets quality-ast-grep quality-jscpd infra-kube-linter infra-checkov infra-kubeconform infra-trivy-config infra-helm-lint docs-build
