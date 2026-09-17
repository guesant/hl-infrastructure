# Checklist operacional

Lista curta para marcar a cada bootstrap, upgrade de versão ou mudança de rede. A regra é uma só: não marca sem conferir de verdade naquela execução. A data ao lado de cada item é a da última vez em que foi conferido num node real, e é atualizada no mesmo commit da mudança que motivou a execução.

| Item | Como conferir | Última execução |
| --- | --- | --- |
| Preflight passou | `just preflight` termina sem `failed` | 2026-09-13 |
| Dry-run mostrou só a mudança esperada | `just bootstrap-check` com diff revisado linha a linha | 2026-09-13 |
| Segunda execução é idempotente | `just bootstrap` de novo termina com `changed=0` | pendente |
| SSH continua acessível por uma sessão nova | `ssh` novo depois de qualquer mudança em `firewall` ou `ssh_hardening` | 2026-09-13 |
| API do k3s fechada para toda rede | `firewall-cmd --zone=public --list-all` e `--zone=tailscale --list-all` sem a 6443; `kubectl` só pelo node (`just kubectl`) | pendente |
| Node `Ready` e Cilium saudável | `just status` para o node, mais `cilium status` sem erro | 2026-09-13 |
| Nenhum placeholder pendente | `just placeholders` termina com `nothing pending`, antes do push que leva segredo ou configuração nova ao cluster | pendente |
| Todo `Application` `Synced` e `Healthy` | `just status` | pendente, `cloudflared` do blog em `Degraded` até existir o token real do túnel |
| Timer de manutenção armado | `systemctl list-timers hl-gc.timer` mostra a próxima execução | 2026-09-13 |
| Módulos do OpenTofu sem deriva | `just tofu-plan-all` termina em `No changes` para todo módulo listado por `just tofu-list` | pendente |
| Login pelo Keycloak em cada aplicação | Dashy, Grafana, Portainer, Argo CD e `guesant.net/admin` entram com o usuário do realm e recusam um usuário fora do grupo `admins` | 2026-09-16, exceto o blog, ainda sem usuário no realm `homelab` |
| Nenhum login local sobrando | O formulário do Grafana e o `admin` do Argo CD desligados; o Portainer CE mantém o formulário, com o `admin` protegido pela senha do `SopsSecret` | pendente até o `bootstrap --tags argocd` que desliga o `admin` |
| Kubeconfig local atualizado | `kubectl get nodes` com `.local/operator/kubeconfig` depois de rotação de certificados | pendente |

Um item marcado como `pendente` ainda não foi conferido num node real desde que a rotina correspondente entrou no repositório.

## Continue por aqui

A [metodologia de mudança](metodologia-de-mudanca.md) explica o porquê de cada item.
