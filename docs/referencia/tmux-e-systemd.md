# tmux e systemd

## tmux: sessão, janela e painel

tmux organiza o terminal em três níveis: uma sessão agrupa uma ou mais janelas, e cada janela pode dividir seu espaço em um ou mais painéis. Uma sessão continua rodando no servidor mesmo depois que o terminal que a criou fecha ou a conexão SSH cai; reconectar recupera exatamente o estado onde a sessão foi deixada.

Esse é o motivo de tmux ser a ferramenta certa para qualquer trabalho de longa duração num host remoto, como uma atualização ou uma migração que não pode morrer junto com um link instável. O ponto que importa entender antes de depender disso: iniciar a sessão tmux antes de começar o trabalho é o que garante essa sobrevivência; anexar a uma sessão depois que um comando já está rodando fora dela não recupera esse comando específico.

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `tmux new -s deploy` | Iniciar um trabalho que deve sobreviver à desconexão. | Nomear a sessão facilita reconectar com várias sessões abertas, e evita reconectar por engano à sessão errada. |
| `tmux attach -t deploy` | Reconectar depois de uma queda de SSH. | Falha com erro claro se a sessão não existir mais, o que distingue "a sessão foi encerrada" de "a conexão caiu, mas a sessão continua lá". |
| `Ctrl+b d` | Sair deliberadamente preservando o trabalho, sem fechar a conexão. | `Ctrl+b` é o prefixo padrão: todo atalho solta `Ctrl+b` e depois pressiona a tecla seguinte, não é uma combinação simultânea. |
| `tmux ls` | Confirmar quais sessões existem, ou se uma esperada ainda está viva. | Mostra nome, número de janelas e se está `attached` no momento. |
| `Ctrl+b %` / `Ctrl+b "` | Organizar comandos relacionados visíveis ao mesmo tempo (um painel com `logs -f`, outro livre). | Janelas servem melhor a tarefas não relacionadas (cada uma ocupa a tela inteira); painéis servem a tarefas relacionadas que precisam ficar visíveis juntas. |
| `Ctrl+b [` (copy mode) | Rolar para ler saída que já passou do topo, ou copiar um trecho de texto. | O scroll normal do terminal não funciona dentro do tmux, porque ele controla o próprio buffer de tela; o buffer de copy mode é interno ao tmux, separado da área de transferência do sistema. |

`screen` (GNU Screen) resolve o mesmo problema central, mais antigo que tmux; os comandos equivalentes usam um prefixo diferente do de tmux, como mostra a tabela abaixo.

| tmux | screen | Ação |
| --- | --- | --- |
| `tmux new -s nome` | `screen -S nome` | criar sessão nomeada |
| `Ctrl+b d` | `Ctrl+a d` | desanexar |
| `tmux attach -t nome` | `screen -r nome` | reconectar |

A diferença prática está em divisão de painéis, nativa e mais rica em tmux desde o início, tardia e mais limitada em screen, e na facilidade de automação: o arquivo de configuração e os comandos de scripting de tmux acompanham automação melhor do que o equivalente em screen.

Vale escolher screen só quando ele já está instalado num host minimalista onde tmux não pode ser adicionado, ou quando a necessidade é só um detach/reattach simples sem painéis; fora disso, tmux é a escolha mais capaz para o mesmo trabalho.

## systemd

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `sudo systemctl start\|stop\|restart nginx` | Ligar, desligar ou reiniciar um serviço. | `start` age imediatamente sem alterar o comportamento no próximo boot; `enable` adiciona ao início automático sem iniciar agora, combine os dois quando quiser as duas coisas de uma vez. |
| `journalctl -u nginx -f -b` | Depurar um serviço ou investigar erro de inicialização. | `-u` filtra por unidade; `-b` restringe aos logs desde o último boot, descartando ruído de execuções anteriores. |
| `sudo systemctl reload nginx` vs. `restart` | Aplicar configuração nova sem indisponibilidade, quando o serviço suportar. | `reload` pede ao processo que releia a configuração mantendo conexões abertas, nem todo serviço implementa isso; `restart` encerra e sobe um processo novo, com uma janela real de indisponibilidade que `reload` evita. `daemon-reload` é obrigatório sempre que um arquivo `.service` é editado, mesmo sem o serviço em si ter mudado. |
| `systemctl list-timers` | Agendar tarefas recorrentes (backup, limpeza), alternativa ao cron. | Timers do systemd suportam atraso aleatório de início e execução retroativa de tarefas perdidas (`Persistent=true`), recursos que o cron tradicional não tem nativamente. |
| Criar `/etc/systemd/system/myapp.service` | Rodar uma aplicação customizada como serviço gerenciado. | `[Unit].After` garante ordem de inicialização (por exemplo, só depois da rede); `Type=simple` (padrão) considera o serviço iniciado assim que o `ExecStart` sobe, `Type=forking` é para daemons tradicionais que fazem fork de si mesmos. |
| `systemctl get-default` / `systemctl isolate <target>` | Entender ou mudar o modo de boot atual. | `multi-user.target` é o modo servidor sem interface gráfica; `rescue.target` é o modo de emergência com o mínimo de serviços ativos, útil para recuperação. |

## Fragmentos de unit systemd

Serviço oneshot, o tipo que uma unit de timer dispara:

```ini
[Unit]
Description=Minha tarefa
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/minha-tarefa.sh
```

`Type=oneshot` é para uma tarefa que executa e termina, diferente de `Type=simple`, usado por processos de longa duração.

Serviço de longa duração com limites de recursos via cgroups e um intervalo antes de reiniciar:

```ini
[Unit]
Description=Minha aplicação
After=network.target

[Service]
Type=simple
User=myuser
ExecStart=/usr/bin/myapp
Restart=on-failure
RestartSec=5
MemoryMax=512M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
```

| Campo | Papel |
| --- | --- |
| `MemoryMax` | teto de memória do processo |
| `CPUQuota` | teto de CPU do processo |
| `RestartSec` | intervalo antes de tentar reiniciar |

Esse intervalo evita entrar num loop de reinícios imediatos depois de uma falha recorrente.

Timer diário, que aciona a unidade de serviço de mesmo nome:

```ini
[Unit]
Description=Agenda minha-tarefa diariamente

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

`OnCalendar=daily` equivale a rodar à meia-noite; `Persistent=true` executa a tarefa perdida assim que o sistema volta a ligar, caso o horário programado tenha passado com a máquina desligada.

Timer relativo ao boot ou à última execução, em vez de um horário fixo de calendário:

```ini
[Timer]
OnBootSec=15min
OnUnitActiveSec=1h
RandomizedDelaySec=300
```

| Campo | Comportamento |
| --- | --- |
| `OnBootSec` | dispara a primeira execução um tempo fixo após o boot |
| `OnUnitActiveSec` | repete a partir do fim da execução anterior |
| `RandomizedDelaySec` | espalha a execução numa janela aleatória |

Combine os dois primeiros quando o intervalo entre execuções importa mais que o horário exato; o terceiro evita que várias instâncias do mesmo timer, em hosts diferentes, disparem todas no mesmo segundo.

Drop-in, para sobrescrever parte de uma unit sem editar o arquivo original:

```bash
sudo systemctl edit myapp.service
```

```ini
[Service]
Environment=DEBUG=true
MemoryMax=1G
```

`systemctl edit` abre um editor e grava o conteúdo num arquivo de override próprio, sem alterar a unit original (por exemplo, uma instalada por um pacote); os campos declarados no drop-in substituem os equivalentes da unit base, os demais continuam herdados dela normalmente.

## Continue por aqui

[Fail2ban](../aprender/sistemas/linux/fail2ban.md), [atualizações automáticas](../aprender/sistemas/linux/automatic-updates.md) e [journal persistente](../aprender/sistemas/linux/journald.md) cobrem timers do systemd como alternativa ao cron com mais profundidade conceitual.
