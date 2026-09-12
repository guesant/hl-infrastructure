set shell := ["bash", "-uc"]

kubeconfig := "ansible/kubeconfig"

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
