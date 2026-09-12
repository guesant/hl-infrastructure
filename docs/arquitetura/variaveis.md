# Variáveis

Toda variável declarada em [ansible/group_vars/all.example.yml](https://github.com/guesant/hl-infrastructure/blob/main/ansible/group_vars/all.example.yml). O arquivo real, `all.yml`, não é rastreado pelo git; só o `.example` fica versionado.

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_version` | Versão do k3s instalada pelo script oficial | role `k3s` |
| `helm_version` | Versão do binário Helm usado tanto pelo Ansible quanto pela renderização local de charts | roles `cilium`, `cert-manager`, `argocd`, `argocd-image-updater`, `cnpg`, `cnpg-barman-plugin`, `sealed-secrets`; `.tools/render-charts.sh` |
| `cilium_version` | Versão do chart Helm do Cilium | role `cilium` |
| `cilium_cli_version` | Versão do binário `cilium-cli`, usado só para inspeção (`cilium status`), nunca para instalar | role `cilium` |
| `cert_manager_chart_version` | Versão do chart Helm do cert-manager | role `cert-manager` |
| `argocd_chart_version` | Versão do chart Helm do ArgoCD | role `argocd` |
| `argocd_image_updater_chart_version` | Versão do chart Helm do Argo CD Image Updater | role `argocd-image-updater` |
| `cnpg_chart_version` | Versão do chart Helm do operador CloudNativePG | role `cnpg` |
| `cnpg_barman_plugin_chart_version` | Versão do chart Helm do plugin Barman Cloud | role `cnpg-barman-plugin` |
| `sealed_secrets_chart_version` | Versão do chart Helm do controlador Sealed Secrets | role `sealed-secrets` |
| `k3s_api_allowed_cidrs` | Lista de CIDRs autorizados a acessar a porta da API do k3s no firewall | role `os-prerequisites` |
| `ssh_root_authorized_key` | Chave pública SSH autorizada para login como root | role `ssh_hardening` |
| `argocd_github_webhook_secret` | Segredo compartilhado usado para validar o webhook do GitHub que acelera a sincronização do Argo | role `argocd` |

## Continue por aqui

Para ver como cada versão de chart é mantida em dia automaticamente, veja [Helm e os charts](helm-e-charts.md).
