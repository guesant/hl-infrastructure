# Variáveis

<!-- source-of-trust paths="ansible/group_vars/all/secrets.example.yml ansible/group_vars/all/tailscale.yml ansible/group_vars/all/authorized_keys.yml" -->

As variáveis do Ansible vivem em alguns arquivos dentro de [ansible/group_vars/all/](https://github.com/guesant/hl-infrastructure/tree/main/ansible/group_vars/all), que o Ansible mescla como se fossem um só. A separação segue quem escreve cada um e se o conteúdo pode ficar em texto claro: versão de software, hostname e chave pública podem; endereço de rede interna e credencial não, e por isso vão para o arquivo cifrado mesmo quando não são segredo no sentido estrito.

Um dos arquivos não declara configuração do cluster e sim como chegar nele: `connection.yml` exige a checagem estrita de host key contra o `known_hosts` do operador, de modo que uma host key divergente derruba a conexão antes da primeira task.

`versions.yml` é versionado e é o arquivo real, sem cópia: toda versão de binário e de chart fica nele, o Renovate abre PR contra ele, e o Ansible, o script de renderização e a CI leem dele.

Uma versão mergeada no branch principal é a versão que o próximo bootstrap instala, sem passo manual no meio. Boa parte das entradas vem em par, a versão e o hash SHA-256 do artefato correspondente, e as duas andam juntas: um bump que troque a versão e deixe o hash antigo para trás falha na conferência antes de instalar qualquer coisa.

`secrets.sops.yaml` guarda o que é de cada instalação, rede e segredo, cifrado com SOPS para os mesmos destinatários do arquivo de configuração e commitado. O Ansible o decifra sozinho ao carregar as variáveis, pelo vars plugin da coleção `community.sops`, usando a identidade da Secure Enclave do operador; o valor em claro só existe na memória do processo.

`secrets.example.yml` é o modelo versionado com placeholders, e o [primeiro bootstrap](../operacional/primeiro-bootstrap.md) é o único lugar que pede para partir dele.

Esta página não rastreia `versions.yml` para o gate de deriva de documentação: o Renovate bumpa um valor ali quase todo dia, e um bump isolado não muda nada que a tabela abaixo descreva, só o valor atual de uma variável que já existe.

A página precisa de revisão quando uma variável é adicionada ou removida, o que também muda os arquivos de roles ou o `ansible/site.yml`, já rastreados pela página de [Ansible](ansible.md). Quem cobra isso é o script de deriva de documentação, que compara o último commit dos caminhos declarados no marcador com o último commit da página e falha quando a fonte é a mais nova das duas.

## versions.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `k3s_version` | Versão do k3s instalada pelo script oficial | role `k3s` |
| `k3s_install_script_sha256` | SHA-256 do `install.sh` do k3s na tag declarada, baixado do repositório do projeto em vez de `get.k3s.io`; muda junto com `k3s_version` | role `k3s` |
| `helm_version` | Versão do binário Helm usado tanto pelo Ansible quanto pela renderização local de charts | roles `cilium`, `argocd`; `.tools/render-charts.sh` |
| `cilium_version` | Versão do chart Helm do Cilium | role `cilium` |
| `cilium_chart_sha256` | SHA-256 do `.tgz` do chart do Cilium nessa versão, conferido pela role e pelo `render-charts.sh` antes de renderizar | role `cilium`, `.tools/render-charts.sh` |
| `cilium_cli_version` | Versão do binário `cilium-cli`, usado só para inspeção (`cilium status`), nunca para instalar | role `cilium` |
| `argocd_chart_version` | Versão do chart Helm do ArgoCD | role `argocd` |
| `argocd_chart_sha256` | SHA-256 do `.tgz` do chart do Argo CD nessa versão, conferido da mesma forma | role `argocd`, `.tools/render-charts.sh` |
| `kube_bench_version` | Versão do binário `kube-bench` que o Ansible instala no node para inspeção manual | role `kube_bench` |

O cert-manager, o operador CloudNativePG, o sops-secrets-operator e o Kargo não têm entrada aqui: desde que passaram a ser aplicação do ArgoCD em vez de uma role, a versão de cada um vive na própria dependência do Chart.yaml local ([cert-manager](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/operators/cert-manager/Chart.yaml), [cnpg](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/operators/cnpg/Chart.yaml), [sops-secrets-operator](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/operators/sops-secrets-operator/Chart.yaml), [kargo](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/platform/kargo/Chart.yaml)), e o Renovate atualiza cada uma pelo gerenciador nativo de chart Helm, sem precisar do regex customizado que os demais usam.

A dependência fica declarada no `Chart.yaml` de um chart wrapper local, que é o formato que o Renovate entende sem ajuda nenhuma. O efeito prático é que o bump desses componentes não passa pelo Ansible nem espera um bootstrap novo: o Argo sincroniza a versão assim que o pull request entra no branch principal.

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

O arquivo é commitado em texto claro porque chave pública não é segredo. A chave privada correspondente continua fora do repositório, na máquina do operador, apontada por `ansible_ssh_private_key_file` no inventário; se esse campo apontar para um arquivo de chave pública, a role usa o conteúdo dele direto, e se apontar para a chave privada, deriva a pública com `ssh-keygen -y` sobre uma cópia temporária de permissão restrita.

O teto de remoções, na variável `ssh_hardening_max_key_removals`, existe para o caso de a lista chegar truncada por engano: se o node tiver mais chaves não declaradas do que o teto, a role para com a lista na mensagem de erro em vez de reconciliar e trancar alguém para fora.

## tailscale.yml

| Variável | Controla | Consumida por |
| --- | --- | --- |
| `tailscale_hostname` | Nome com que o node aparece na tailnet; o módulo `tofu/tailscale` o procura por esse nome para ler o endereço | role `tailscale`, `tofu/tailscale/terraform.tfvars` |
| `tailscale_internal_domain` | Zona DNS que o `dnsmasq` responde só dentro da tailnet, apontando todo nome para o endereço do node | role `tailscale`, `tofu/tailscale/terraform.tfvars` |
| `tailscale_advertise_tags` | Opcional; tags que o node pede ao entrar na tailnet, só válidas se a ACL da tailnet tiver `tagOwners` para elas | role `tailscale` |

Os valores que aparecem também em `tofu/tailscale/terraform.tfvars` precisam bater nos lugares correspondentes, como o hostname do blog precisa bater entre o OpenTofu e o arquivo de values do blog.

A duplicação tem consequência concreta: o módulo do Tailscale no OpenTofu procura o node na tailnet pelo nome para ler o endereço dele, então um nome divergente não produz erro de configuração, produz uma busca que não encontra nada. Só o par do blog tem gate automático, na checagem de placeholders; os valores da tailnet dependem de quem edita os dois arquivos manter os dois iguais.

A role da chave age não consome nenhuma variável daqui: ela gera o próprio par de chaves com `age-keygen` direto no node, na primeira execução, em vez de receber um valor pronto do arquivo de segredos. Veja [Ansible: as roles do bootstrap](ansible.md) para o porquê.

A consequência de gerar a chave no lugar de recebê-la é que uma reinstalação do node produz um par novo, que precisa entrar no arquivo de destinatários pela recipe de sincronização antes que qualquer segredo volte a ser decifrado ali.

## Continue por aqui

Para ver como cada versão de chart é mantida em dia automaticamente, veja [Helm e os charts](helm-e-charts.md). Para a lista de tudo o que, como a chave privada do node, vive fora do git, veja [estado fora do git](../operacional/estado-fora-do-git.md).
