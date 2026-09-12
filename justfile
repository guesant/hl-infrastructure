set shell := ["bash", "-uc"]

kubeconfig := "ansible/kubeconfig"
actionlint_image := `grep -oE "rhysd/actionlint:[0-9.]+" .github/workflows/lint-actions.yml | head -1`
zizmor_version := `grep -oE 'version: "[0-9.]+"' .github/workflows/lint-actions.yml | grep -oE "[0-9.]+" | head -1`
gitleaks_image := `grep -oE "zricethezav/gitleaks:v[0-9.]+" .github/workflows/security.yml | head -1`
osv_scanner_image := `grep -oE "ghcr.io/google/osv-scanner:v[0-9.]+" .github/workflows/security.yml | head -1`
trivy_image := `grep -oE "aquasec/trivy:[0-9.]+" .github/workflows/security.yml | head -1`
ast_grep_version := `grep -oE "@ast-grep/cli@[0-9.]+" .github/workflows/quality.yml | grep -oE "[0-9.]+" | head -1`
jscpd_version := `grep -oE "jscpd@[0-9.]+" .github/workflows/quality.yml | grep -oE "[0-9.]+" | head -1`
kube_linter_image := `grep -oE "stackrox/kube-linter:v[0-9.]+" .github/workflows/infra-lint.yml | head -1`
checkov_image := `grep -oE "bridgecrew/checkov:[0-9.]+" .github/workflows/infra-lint.yml | head -1`
helm_version := `grep -oE 'helm_version:\s*v[0-9.]+' ansible/group_vars/all.example.yml | grep -oE "[0-9.]+"`

bootstrap:
    ansible-galaxy collection install -r ansible/requirements.yml
    ansible-playbook -i ansible/inventory.ini ansible/site.yml

kubeconfig:
    echo "export KUBECONFIG={{justfile_directory()}}/{{kubeconfig}}"

fetch-cert:
    kubeseal --kubeconfig {{kubeconfig}} --fetch-cert > sealed-secrets-cert.pem

seal namespace name plain_file:
    kubeseal --cert sealed-secrets-cert.pem --namespace {{namespace}} --name {{name}} < {{plain_file}}

status:
    kubectl --kubeconfig {{kubeconfig}} get nodes
    kubectl --kubeconfig {{kubeconfig}} -n argocd get applications

lint-actions:
    test -n "{{actionlint_image}}" || (echo "could not extract the actionlint image from lint-actions.yml" >&2 && exit 1)
    test -n "{{zizmor_version}}" || (echo "could not extract the zizmor version from lint-actions.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo --entrypoint sh {{actionlint_image}} \
        -c "actionlint -color .github/workflows/*.yml"
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo ghcr.io/zizmorcore/zizmor:{{zizmor_version}} \
        --no-progress /repo/.github/workflows

security-gitleaks:
    test -n "{{gitleaks_image}}" || (echo "could not extract the gitleaks image from security.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo {{gitleaks_image}} \
        detect --source /repo --config /repo/.gitleaks.toml --redact -v

security-osv-scanner:
    test -n "{{osv_scanner_image}}" || (echo "could not extract the osv-scanner image from security.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo {{osv_scanner_image}} \
        scan source --recursive --experimental-exclude rendered --allow-no-lockfiles /repo

security-trivy-fs:
    test -n "{{trivy_image}}" || (echo "could not extract the trivy image from security.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo {{trivy_image}} \
        fs --scanners vuln,secret --skip-dirs rendered /repo

quality-ast-grep:
    test -n "{{ast_grep_version}}" || (echo "could not extract the ast-grep version from quality.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo node:20-slim \
        npx --yes -p @ast-grep/cli@{{ast_grep_version}} -- ast-grep scan --config .ast-grep/sgconfig.yml ansible

quality-jscpd:
    test -n "{{jscpd_version}}" || (echo "could not extract the jscpd version from quality.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo node:20-slim \
        npx --yes -p jscpd@{{jscpd_version}} -- jscpd .

infra-render-charts:
    test -n "{{helm_version}}" || (echo "could not extract helm_version from ansible/group_vars/all.example.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo --entrypoint bash alpine/helm:{{helm_version}} \
        hack/render-charts.sh

infra-kube-linter: infra-render-charts
    test -n "{{kube_linter_image}}" || (echo "could not extract the kube-linter image from infra-lint.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo {{kube_linter_image}} \
        lint --config .kube-linter.yaml --ignore-paths rendered/cilium.yaml rendered argocd

infra-checkov: infra-render-charts
    test -n "{{checkov_image}}" || (echo "could not extract the checkov image from infra-lint.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo {{checkov_image}} \
        --directory rendered --directory argocd --framework kubernetes \
        --check CKV_K8S_16,CKV_K8S_18,CKV_K8S_19 --skip-path rendered/cilium.yaml --compact

infra-trivy-config: infra-render-charts
    test -n "{{trivy_image}}" || (echo "could not extract the trivy image from security.yml" >&2 && exit 1)
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo {{trivy_image}} \
        config --misconfig-scanners kubernetes --skip-dirs rendered/cilium.yaml .
