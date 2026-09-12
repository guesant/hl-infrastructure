# Variáveis

<!-- source-of-trust paths="ansible/group_vars/all/versions.yml ansible/group_vars/all/secrets.example.yml" -->

As variáveis do Ansible vivem em dois arquivos dentro de [ansible/group_vars/all/](https://github.com/guesant/hl-infrastructure/tree/main/ansible/group_vars/all), que o Ansible mescla como se fossem um só. A separação segue quem escreve cada um.

`versions.yml` é versionado e é o arquivo real, sem cópia: toda versão de binário e de chart fica nele, o Renovate abre PR contra ele, e o Ansible, o `render-charts.sh` e a CI leem dele. Uma versão mergeada em `main` é a versão que o próximo `bootstrap` instala, sem passo manual entre os dois.

`secrets.yml` não é rastreado pelo git e guarda o que é de cada instalação: segredo, rede e chave. `secrets.example.yml` é o modelo versionado com placeholders, e o [tutorial](../tutorial/primeiro-bootstrap.md) é o único lugar que pede para copiá-lo.

## versions.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_version` | Versão do k3s instalada pelo script oficial | role `k3s` |
| `helm_version` | Versão do binário Helm usado tanto pelo Ansible quanto pela renderização local de charts | roles `cilium`, `cert_manager`, `argocd`, `argocd_image_updater`, `cnpg`, `cnpg_barman_plugin`, `sealed_secrets`; `.tools/render-charts.sh` |
| `cilium_version` | Versão do chart Helm do Cilium | role `cilium` |
| `cilium_cli_version` | Versão do binário `cilium-cli`, usado só para inspeção (`cilium status`), nunca para instalar | role `cilium` |
| `cert_manager_chart_version` | Versão do chart Helm do cert-manager | role `cert_manager` |
| `argocd_chart_version` | Versão do chart Helm do ArgoCD | role `argocd` |
| `argocd_image_updater_chart_version` | Versão do chart Helm do Argo CD Image Updater | role `argocd_image_updater` |
| `cnpg_chart_version` | Versão do chart Helm do operador CloudNativePG | role `cnpg` |
| `cnpg_barman_plugin_chart_version` | Versão do chart Helm do plugin Barman Cloud | role `cnpg_barman_plugin` |
| `sealed_secrets_chart_version` | Versão do chart Helm do controlador Sealed Secrets | role `sealed_secrets` |

## secrets.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_api_allowed_cidrs` | Lista de CIDRs autorizados a acessar a porta da API do k3s no firewall | role `firewall` |
| `bootstrap_app_repo_url` | Opcional; URL do repositório que a `Application` root sincroniza, por padrão este repositório | role `bootstrap_app` |
| `ssh_root_authorized_key` | Chave pública SSH autorizada para login como root | role `ssh_hardening` |
| `argocd_github_webhook_secret` | Segredo compartilhado usado para validar o webhook do GitHub que acelera a sincronização do Argo | role `argocd` |

## Continue por aqui

Para ver como cada versão de chart é mantida em dia automaticamente, veja [Helm e os charts](helm-e-charts.md). Para a lista de tudo o que, como `secrets.yml`, vive fora do git, veja [estado fora do git](../operacional/estado-fora-do-git.md).
