set shell := ["bash", "-uc"]

kubeconfig := "ansible/kubeconfig"
actionlint_image := `grep -oE "rhysd/actionlint:[0-9.]+" .github/workflows/lint-actions.yml | head -1`
zizmor_version := `grep -oE 'version: "[0-9.]+"' .github/workflows/lint-actions.yml | grep -oE "[0-9.]+" | head -1`
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

_build target:
    docker build --target {{target}} -t hl-infra/{{target}} {{justfile_directory()}}/.docker

_build-helm:
    test -n "{{helm_version}}" || (echo "could not extract helm_version from ansible/group_vars/all.example.yml" >&2 && exit 1)
    docker build --target helm --build-arg HELM_VERSION={{helm_version}} -t hl-infra/helm {{justfile_directory()}}/.docker

security-gitleaks: (_build "gitleaks")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/gitleaks \
        detect --source /repo --config /repo/.config/gitleaks.toml \
        --gitleaks-ignore-path /repo/.config/gitleaksignore --redact -v

security-osv-scanner: (_build "osv-scanner")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/osv-scanner \
        scan source --recursive --experimental-exclude rendered --allow-no-lockfiles /repo

security-trivy-fs: (_build "trivy")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/trivy \
        fs --scanners vuln,secret --skip-dirs rendered /repo

quality-ast-grep: (_build "ast-grep")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/ast-grep \
        ast-grep scan --config .ast-grep/sgconfig.yml .

quality-jscpd: (_build "jscpd")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/jscpd jscpd --config .config/jscpd.json

infra-render-charts: _build-helm
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo --entrypoint bash hl-infra/helm .tools/render-charts.sh

infra-kube-linter: infra-render-charts (_build "kube-linter")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/kube-linter \
        lint --config .config/kube-linter.yaml --ignore-paths rendered/cilium.yaml rendered argocd

infra-checkov: infra-render-charts (_build "checkov")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/checkov \
        --directory rendered --directory argocd --framework kubernetes \
        --check CKV_K8S_16,CKV_K8S_18,CKV_K8S_19 --skip-path rendered/cilium.yaml --compact

infra-trivy-config: infra-render-charts (_build "trivy")
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo hl-infra/trivy \
        config --misconfig-scanners kubernetes --skip-dirs rendered/cilium.yaml .
