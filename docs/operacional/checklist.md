# Checklist operacional

Lista curta para marcar a cada bootstrap, upgrade de versão ou mudança de rede. A regra é uma só: não marca sem conferir de verdade naquela execução. A data ao lado de cada item é a da última vez em que foi conferido num node real, e é atualizada no mesmo commit da mudança que motivou a execução.

| Item | Como conferir | Última execução |
| --- | --- | --- |
| Preflight passou | `just preflight -K` termina sem `failed` | pendente |
| Dry-run mostrou só a mudança esperada | `just bootstrap-check -K` com diff revisado linha a linha | pendente |
| Segunda execução é idempotente | `just bootstrap -K` de novo termina com `changed=0` | pendente |
| SSH continua acessível por uma sessão nova | `ssh` novo depois de qualquer mudança em `firewall` ou `ssh_hardening` | pendente |
| API do k3s só responde dos CIDRs permitidos | `firewall-cmd --list-rich-rules` mostra só `k3s_api_allowed_cidrs` na 6443 | pendente |
| Node `Ready` e Cilium saudável | `kubectl get nodes` e `cilium status` sem erro | pendente |
| Todo `Application` `Synced` e `Healthy` | `kubectl -n argocd get applications` | pendente |
| Backup do Postgres recente | `lastSuccessfulBackup` do `Cluster` nas últimas 24 h | pendente |
| Timer de manutenção armado | `systemctl list-timers hl-gc.timer` mostra a próxima execução | pendente |
| Kubeconfig local atualizado | `kubectl get nodes` com `ansible/kubeconfig` depois de rotação de certificados | pendente |

Um item marcado como `pendente` ainda não foi conferido num node real desde que a rotina correspondente entrou no repositório.

## Continue por aqui

A [metodologia de mudança](metodologia-de-mudanca.md) explica o porquê de cada item.
