# Mapa de controles

Um inventário do que o repositório de fato garante, por componente, com a evidência verificável de cada garantia: o gate, o arquivo ou o comando que prova que o controle existe. Não é uma norma; é o que se pode afirmar hoje sem depender da memória de quem opera.

| Componente | Tema | Controle | Evidência |
| --- | --- | --- | --- |
| Repositório | Segredos | Nenhum segredo no git; valores reais só em `secrets.yml` (ignorado), em `SopsSecret` e em `tofu/**/*.sops.env` | `.gitignore`, job `gitleaks` sobre todo o histórico, `trivy-fs`, job `sopssecrets` |
| Repositório | Integridade de dependências | Toda action, imagem, chart e binário pinado por versão ou SHA | `.github/workflows/*.yml` (SHA em todo `uses`), `.tools/docker/Dockerfile`, `versions.yml`, check `check-images-pinned.sh` |
| Repositório | Atualização | Renovate abre PR para toda dependência, com sete dias de carência | `.github/renovate.json`, dependency dashboard |
| CI | Privilégio | `contents: read` por padrão; escrita só no `renovate`, isolado num environment | `permissions:` em cada workflow, `zizmor` a cada push |
| CI | Supply chain de workflows | Sem `persist-credentials`, sem injeção via template | `zizmor`, `actionlint` |
| Manifestos | Conformidade de schema | Todo recurso renderizado válido contra a API e as CRDs | job `kubeconform` |
| Manifestos | Privilégio de contêiner | Sem privilegiado, sem namespace do host, sem montagem sensível, fora a CNI | `.config/kube-linter.yaml`, `checkov` com `CKV_K8S_16,18,19`, `trivy config` |
| Ansible | Correção | Perfil `production` do ansible-lint, `changed_when` explícito, `assert` de variáveis em toda role | job `ansible-lint`, primeira task de cada role |
| Ansible | Integridade de binários | k3s, Helm e cilium-cli verificados contra o checksum publicado pelo projeto | roles `k3s` e `cilium`, campo `checksum` de cada `get_url` |
| Ansible | Resiliência de upgrade | Um chart que muda `selector` entre versões não trava o bootstrap; o objeto conflitante é recriado, nunca aplicado às cegas | role `recreate_immutable_conflicts` |
| Node | Acesso | SSH só por chave, root só com chave, fail2ban | roles `ssh_hardening` e `fail2ban` |
| Node | Rede | Firewall ligado, API do k3s só dos CIDRs do operador, SSH nunca removido da zona | role `firewall`, `assert` antes do reload |
| Node | Kernel | sysctls de hardening, reboot automático após oops | role `sysctl_hardening` |
| Node | Auditoria | auditd para chamadas de sistema, audit log do API server para toda escrita | roles `auditd` e `k3s`, `audit-policy.yaml` |
| Node | Atualizações | Correções de segurança automáticas | role `unattended_upgrades` |
| Node | Capacidade | Journal limitado, GC semanal de imagens e ReplicaSets | role `maintenance`, `hl-gc.timer` |
| ArgoCD | Segregação | Satélites só criam recurso de namespace; `default` esvaziado | `argocd/root/project-*.yaml` |
| ArgoCD | Comportamento de sync | Server-side apply, prune por último, retry com backoff | `syncPolicy` em todo `Application` |
| Imagens | Proveniência | Só tags imutáveis `sha-<commit>` são promovidas | `ImageUpdater` de cada satélite com `allowTags` |
| Cloudflare | Privilégio | O API token do OpenTofu só edita túnel e DNS, nunca cria outros tokens | permissões do token no dashboard, [primeiro bootstrap](../operacional/primeiro-bootstrap.md) |
| Cloudflare | Segredos no state | State do OpenTofu cifrado, recusado em texto claro; o token do túnel nunca passa pelo OpenTofu | `tofu/cloudflare/encryption.tf` com `enforced = true`, `.tools/cloudflare-tunnel-token.sh`, job `tofu` |
| Repositório | Rotação de segredos | Todo arquivo cifrado tem prazo de rotação; vencido, a execução agendada da CI fica vermelha | job `secret-age`, `.config/secret-max-age.conf` |
| Configuração | Valores de exemplo | Nenhum `REPLACE_WITH_` ou `.invalid` chega a um `apply` ou a um deploy sem ser notado, nem dentro de arquivo cifrado | job `placeholders` em todo push para o texto claro, validações em `tofu/cloudflare/variables.tf`, recusa em `.tools/tofu-run.sh`, `just placeholders` antes do push para o que está cifrado |
| Dados | Recuperação | Nenhum hoje: o backup contínuo do Postgres foi desligado de propósito, e a perda do volume do node é perda total dos dados | [estado fora do git](../operacional/estado-fora-do-git.md), [restaurar o node](../operacional/restaurar-o-node.md) |
| Node | Segredos em repouso | `Secret` do Kubernetes cifrados no datastore do k3s, com recifragem dos que já existiam | `secrets-encryption` em `ansible/roles/k3s/templates/config.yaml.j2`, `k3s secrets-encrypt status` checado pela role |
| Node | Superfície | kubeconfig do node só para root, `rpcbind` parado e mascarado | roles `k3s` e `os_prerequisites` |
| Pods | Pod Security Admission | `enforce restricted` em todo namespace de workload; namespace novo sem o label falha a CI | `managedNamespaceMetadata` nas `Application`, `argocd/apps/platform/namespaces`, role `argocd`, job `pod-security` |
| Pods | Privilégio mínimo | ServiceAccount própria sem token, sistema de arquivos raiz somente leitura, seccomp `RuntimeDefault` e `drop: ALL` | values do blog, do cloudflared e do sops-secrets-operator |
| Rede | Listas de liberação | Cada namespace só fala com o que usa; ainda em modo auditoria no Cilium | `argocd/apps/platform/network-policies`, `cilium-egress.yaml` do blog, Hubble |
| Cluster | Benchmark | kube-bench semanal nas checagens de RBAC e política do CIS para k3s, sem root e sem acesso a `Secret` | `argocd/apps/platform/kube-bench` |
| Documentação | Fidelidade | Página cuja fonte mudou sem revisão falha a CI | `.tools/check-doc-drift.sh`, marcadores `source-of-trust` |

## O que este mapa não cobre

Observabilidade (métricas, alertas, logs centralizados) não tem controle declarado ainda; hoje o sinal de que algo falhou é o Argo marcar `Degraded` ou o serviço parar de responder. É a lacuna mais visível da tabela e a próxima a fechar.

## Continue por aqui

O [modelo de ameaças](modelo-de-ameacas.md) diz de que cada controle protege; [a pipeline de CI](ci.md) detalha os gates citados como evidência. O [checklist de segurança](checklist-de-seguranca.md) faz o caminho inverso: parte do que guias públicos de GitOps, DevOps, Linux, Terraform e Kubernetes recomendam e mostra também o que falta.
