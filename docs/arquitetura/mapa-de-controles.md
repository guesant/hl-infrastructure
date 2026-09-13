# Mapa de controles

Um inventário do que o repositório de fato garante, por componente, com a evidência verificável de cada garantia: o gate, o arquivo ou o comando que prova que o controle existe. Não é uma norma; é o que se pode afirmar hoje sem depender da memória de quem opera.

| Componente | Tema | Controle | Evidência |
| --- | --- | --- | --- |
| Repositório | Segredos | Nenhum segredo no git; valores reais só em `secrets.yml` (ignorado) e em `SealedSecret` | `.gitignore`, job `gitleaks` sobre todo o histórico, `trivy-fs` |
| Repositório | Integridade de dependências | Toda action, imagem, chart e binário pinado por versão ou SHA | `.github/workflows/*.yml` (SHA em todo `uses`), `.tools/docker/Dockerfile`, `versions.yml`, check `check-images-pinned.sh` |
| Repositório | Atualização | Renovate abre PR para toda dependência, com sete dias de carência | `.config/renovate.json`, dependency dashboard |
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
| Dados | Recuperação | Backup contínuo do Postgres em object storage, restauração documentada; depende de cada satélite selar as próprias credenciais do bucket | `ObjectStore` e `ScheduledBackup` do satélite, [restaurar o node](../operacional/restaurar-o-node.md), [checklist operacional](../operacional/checklist.md) |
| Documentação | Fidelidade | Página cuja fonte mudou sem revisão falha a CI | `.tools/check-doc-drift.sh`, marcadores `source-of-trust` |

## O que este mapa não cobre

Observabilidade (métricas, alertas, logs centralizados) não tem controle declarado ainda; hoje o sinal de que algo falhou é o Argo marcar `Degraded` ou o serviço parar de responder. É a lacuna mais visível da tabela e a próxima a fechar.

## Continue por aqui

O [modelo de ameaças](modelo-de-ameacas.md) diz de que cada controle protege; [a pipeline de CI](ci.md) detalha os gates citados como evidência.
