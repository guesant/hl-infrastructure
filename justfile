set shell := ["bash", "-uc"]

kubeconfig := "ansible/kubeconfig"
actionlint_image := `grep -oE "rhysd/actionlint:[0-9.]+" .github/workflows/lint-actions.yml | head -1`
zizmor_version := `grep -oE 'version: "[0-9.]+"' .github/workflows/lint-actions.yml | grep -oE "[0-9.]+" | head -1`

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
