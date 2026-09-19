# Comandos de firewall, logs e valores aleatórios

## Firewall

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `ufw status verbose` / `firewall-cmd --list-all` / `nft list ruleset` | Ver rapidamente o que está liberado, primeiro passo antes de investigar por que uma porta não responde. | `nft list ruleset` mostra o estado real das chains no kernel, a fonte de verdade final quando o que UFW ou firewalld reportam não bate com o comportamento observado. Nunca rode UFW e firewalld ativos ao mesmo tempo no mesmo host; confirme qual está de fato ativo com `systemctl is-active`. |
| `firewall-cmd --query-port=443/tcp` | Distinguir "porta não liberada no firewall" de "serviço não escutando" ou "pacote bloqueado em outra camada". | Confirma só a política estática do host; uma porta liberada localmente ainda pode ser bloqueada por um firewall de borda, um security group de nuvem, ou uma `NetworkPolicy` do Kubernetes entre Pods. |
| `journalctl -k \| grep '\[UFW BLOCK\]'` (UFW) / `firewall-cmd --set-log-denied=all` (firewalld) | Confirmar se um pacote está sendo descartado pelo firewall do host, quando uma conexão falha sem erro do lado da aplicação. | O nível padrão de log do UFW não registra todo pacote descartado; o firewalld não loga negações por padrão até habilitar explicitamente; o nftables não tem log implícito nenhum, uma regra de `drop` só aparece no log se a própria regra incluir uma ação `log` antes dela. |

## Logs (journal e kernel)

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `journalctl -r` / `journalctl -f` | Visão geral do host antes de saber qual serviço investigar. | Sem `-u`, mistura todas as unidades e o kernel na mesma linha do tempo; `--no-pager` evita o paginador ao redirecionar para outro comando ou arquivo. |
| `journalctl --list-boots` / `journalctl -b -1` | Investigar uma falha anterior a uma reinicialização (travamento, kernel panic, corte de energia). | O índice de boot é relativo ao atual (`0`); a disponibilidade de boots antigos depende do journal persistente já estar habilitado, veja [Fail2ban, atualizações automáticas e journal persistente](../aprender/fail2ban-atualizacoes-automaticas-e-journal.md). |
| `journalctl -p err` | Reduzir um volume grande de log quando o sintoma é genérico e não há unidade específica para filtrar. | `-p <nível>` inclui o nível informado e todos os mais graves; depende da aplicação classificar corretamente suas mensagens, uma que grava tudo como `info` não aparece num filtro por `err` mesmo relatando uma falha real no texto. |
| `dmesg -T` / `journalctl -k` | Investigar eventos que o kernel reporta direto, sem passar por um serviço: hardware, módulos, OOM killer, erro de filesystem em nível de bloco. | `dmesg` lê um buffer circular, entradas antigas podem já ter sido descartadas; `journalctl -k` mostra o mesmo conteúdo herdando os filtros de prioridade/boot/intervalo do `journalctl`. |

## Valores aleatórios

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `openssl rand -base64 16` | Senhas iniciais, secrets, tokens. | Base64 ocupa cerca de 33% mais caracteres que os bytes de entropia originais. |
| `openssl rand -hex 32` | Tokens de API, session IDs, valores seguros para URL e log. | Hexadecimal usa 2 caracteres por byte; mais legível em log e configuração que base64, ao custo de uma string mais longa para a mesma entropia. |
| `uuidgen` | Identificadores únicos para recursos ou eventos. | Gera por padrão um UUID versão 4 (aleatório); `/proc/sys/kernel/random/uuid` é uma alternativa sem instalar nada no Linux. |
| `echo $((RANDOM % 100 + 1))` | Delay aleatório em script, semente rápida para teste. | `$RANDOM` é específico do Bash, não existe em `sh` puro; `% N` introduz viés leve quando `N` não divide 32768 exatamente. |

## Continue por aqui

[UFW e portas publicadas pelo Docker](../aprender/ufw-e-portas-publicadas-pelo-docker.md), [firewalld](../aprender/firewalld.md) e [Netfilter, nftables e diagnóstico de rede](../aprender/netfilter-nftables-e-diagnostico.md) cobrem o mecanismo por trás dos comandos de firewall acima.
