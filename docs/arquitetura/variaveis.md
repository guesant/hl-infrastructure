# Variáveis

<!-- source-of-trust paths="ansible/group_vars/all/secrets.example.yml ansible/group_vars/all/tailscale.yml ansible/group_vars/all/authorized_keys.yml" -->

As variáveis do Ansible vivem em alguns arquivos dentro de [ansible/group_vars/all/](https://github.com/guesant/hl-infrastructure/tree/main/ansible/group_vars/all), que o Ansible mescla como se fossem um só. A separação segue quem escreve cada um e se o conteúdo pode ficar em texto claro: versão de software, hostname e chave pública podem; endereço de rede interna e credencial não, e por isso vão para o arquivo cifrado mesmo quando não são segredo no sentido estrito.

`versions.yml` é versionado e é o arquivo real, sem cópia: toda versão de binário e de chart fica nele, o Renovate abre PR contra ele, e o Ansible, o `render-charts.sh` e a CI leem dele. Uma versão mergeada em `main` é a versão que o próximo `bootstrap` instala, sem passo manual entre os dois.

`secrets.sops.yaml` guarda o que é de cada instalação, rede e segredo, cifrado com SOPS para os mesmos destinatários de `.sops.yaml` e commitado. O Ansible o decifra sozinho ao carregar as variáveis, pelo vars plugin da coleção `community.sops` ligado em `ansible.cfg`, usando a identidade da Secure Enclave do operador; o valor em claro só existe na memória do processo. `secrets.example.yml` é o modelo versionado com placeholders, e o [primeiro bootstrap](../operacional/primeiro-bootstrap.md) é o único lugar que pede para partir dele.

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

## secrets.sops.yaml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_join_token` | Token de join do k3s, gravado em `config.yaml` na instalação e alvo de `just rotate-token` num node vivo | role `k3s`, `rotate-token.yml` |
| `bootstrap_app_repo_url` | Opcional; URL do repositório que a `Application` root sincroniza, por padrão este repositório | role `bootstrap_app` |
| `argocd_github_webhook_secret` | Segredo compartilhado usado para validar o webhook do GitHub que acelera a sincronização do Argo | role `argocd` |
| `tailscale_auth_key` | Chave de autorização com que o node entra na tailnet; só é lida enquanto o node ainda não entrou, e a role pula tudo o que depende da tailnet enquanto ela for o valor de exemplo | role `tailscale` |

## authorized_keys.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `ssh_hardening_authorized_keys` | A lista completa de chaves públicas que podem entrar por SSH; a role reconcilia o node contra ela, com teto de remoções, e recusa aplicar uma lista que não contenha a chave usada na própria conexão | role `ssh_hardening` |

O arquivo é commitado em texto claro porque chave pública não é segredo. A chave privada correspondente continua fora do repositório, na máquina do operador, apontada por `ansible_ssh_private_key_file` no inventário; se esse campo apontar para um arquivo `.pub`, a role usa o conteúdo dele direto, e se apontar para a chave privada, deriva a pública com `ssh-keygen -y` sobre uma cópia temporária de permissão restrita.

## tailscale.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `tailscale_hostname` | Nome com que o node aparece na tailnet; o módulo `tofu/tailscale` o procura por esse nome para ler o endereço | role `tailscale`, `tofu/tailscale/terraform.tfvars` |
| `tailscale_internal_domain` | Zona DNS que o `dnsmasq` responde só dentro da tailnet, apontando todo nome para o endereço do node | role `tailscale`, `tofu/tailscale/terraform.tfvars` |
| `tailscale_advertise_tags` | Opcional; tags que o node pede ao entrar na tailnet, só válidas se a ACL da tailnet tiver `tagOwners` para elas | role `tailscale` |

Os dois valores que aparecem também em `tofu/tailscale/terraform.tfvars` precisam bater nos dois lugares, como o hostname do blog precisa bater entre o OpenTofu e o `values.yaml` do blog.

A role `sops_age_key` não consome nenhuma variável daqui: ela gera o próprio par de chaves com `age-keygen` direto no node, na primeira execução, em vez de receber um valor pronto de `secrets.sops.yaml`. Veja [Ansible: as roles do bootstrap](ansible.md) para o porquê.

## Continue por aqui

Para ver como cada versão de chart é mantida em dia automaticamente, veja [Helm e os charts](helm-e-charts.md). Para a lista de tudo o que, como a chave privada do node, vive fora do git, veja [estado fora do git](../operacional/estado-fora-do-git.md).
