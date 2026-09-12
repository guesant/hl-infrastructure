set shell := ["bash", "-uc"]

kubeconfig := "ansible/kubeconfig"
actionlint_image := `grep "image: rhysd/actionlint" .github/workflows/lint-actions.yml | sed 's/.*image: //'`
zizmor_version := `grep 'version: "' .github/workflows/lint-actions.yml | sed 's/.*version: "\(.*\)"/\1/'`

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
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo --entrypoint sh {{actionlint_image}} \
        -c "actionlint -color .github/workflows/*.yml"
    docker run --rm -v "{{justfile_directory()}}":/repo -w /repo ghcr.io/zizmorcore/zizmor:{{zizmor_version}} \
        --no-progress /repo/.github/workflows
