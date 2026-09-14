# Variáveis

<!-- source-of-trust paths="ansible/group_vars/all/secrets.example.yml" -->

As variáveis do Ansible vivem em dois arquivos dentro de [ansible/group_vars/all/](https://github.com/guesant/hl-infrastructure/tree/main/ansible/group_vars/all), que o Ansible mescla como se fossem um só. A separação segue quem escreve cada um.

`versions.yml` é versionado e é o arquivo real, sem cópia: toda versão de binário e de chart fica nele, o Renovate abre PR contra ele, e o Ansible, o `render-charts.sh` e a CI leem dele. Uma versão mergeada em `main` é a versão que o próximo `bootstrap` instala, sem passo manual entre os dois.

`secrets.yml` não é rastreado pelo git e guarda o que é de cada instalação: segredo, rede e chave. `secrets.example.yml` é o modelo versionado com placeholders, e o [primeiro bootstrap](../operacional/primeiro-bootstrap.md) é o único lugar que pede para copiá-lo.

Esta página não rastreia `versions.yml` para o gate de deriva de documentação: o Renovate bumpa um valor ali quase todo dia, e um bump isolado não muda nada que a tabela abaixo descreva, só o valor atual de uma variável que já existe. A página precisa de revisão quando uma variável é adicionada ou removida, o que também muda `ansible/roles` ou `ansible/site.yml`, já rastreados pela página de [Ansible](ansible.md).

## versions.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_version` | Versão do k3s instalada pelo script oficial | role `k3s` |
| `helm_version` | Versão do binário Helm usado tanto pelo Ansible quanto pela renderização local de charts | roles `cilium`, `argocd`; `.tools/render-charts.sh` |
| `cilium_version` | Versão do chart Helm do Cilium | role `cilium` |
| `cilium_cli_version` | Versão do binário `cilium-cli`, usado só para inspeção (`cilium status`), nunca para instalar | role `cilium` |
| `argocd_chart_version` | Versão do chart Helm do ArgoCD | role `argocd` |

O cert-manager, o operador CloudNativePG, o sops-secrets-operator e o Argo CD Image Updater não têm entrada aqui: desde que passaram a ser `Application` do ArgoCD em vez de uma role, a versão de cada um vive na própria dependency do `Chart.yaml` local ([cert-manager](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/operators/cert-manager/Chart.yaml), [cnpg](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/operators/cnpg/Chart.yaml), [sops-secrets-operator](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/operators/sops-secrets-operator/Chart.yaml), [argocd-image-updater](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/platform/argocd-image-updater/Chart.yaml)), e o Renovate atualiza cada uma pelo gerenciador nativo de chart Helm, sem precisar do regex customizado que os dois restantes usam.

## secrets.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_api_allowed_cidrs` | Lista de CIDRs autorizados a acessar a porta da API do k3s no firewall | role `firewall` |
| `bootstrap_app_repo_url` | Opcional; URL do repositório que a `Application` root sincroniza, por padrão este repositório | role `bootstrap_app` |
| `ssh_root_authorized_key` | Chave pública SSH autorizada para login como root | role `ssh_hardening` |
| `argocd_github_webhook_secret` | Segredo compartilhado usado para validar o webhook do GitHub que acelera a sincronização do Argo | role `argocd` |

A role `sops_age_key` não consome nenhuma variável daqui: ela gera o próprio par de chaves com `age-keygen` direto no node, na primeira execução, em vez de receber um valor pronto de `secrets.yml`. Veja [Ansible: as roles do bootstrap](ansible.md) para o porquê.

## Continue por aqui

Para ver como cada versão de chart é mantida em dia automaticamente, veja [Helm e os charts](helm-e-charts.md). Para a lista de tudo o que, como `secrets.yml`, vive fora do git, veja [estado fora do git](../operacional/estado-fora-do-git.md).
