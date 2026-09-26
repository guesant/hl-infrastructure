# Comandos de processos, disco e arquivos

## Processos

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `ps aux` / `pstree` | Encontrar um processo, ver estado, CPU e memória. | A coluna `STAT` mostra `S` dormindo, `R` executando, `Z` zumbi. |
| `pgrep -a nginx` | Encontrar o PID de uma aplicação sem o ruído do próprio `grep` na lista. | `ps aux \| grep nginx` sempre lista o próprio `grep`, a menos que a expressão evite a correspondência (`grep [n]ginx`). |
| `kill 1234` / `kill -9 1234` | Encerrar um processo travado ou liberar uma porta. | `TERM` (padrão) dá chance de encerramento limpo; `KILL` (`-9`) é instantâneo e sem limpeza, último recurso. |
| `top` / `htop` | Diagnosticar qual processo consome recursos em excesso. | `top` já vem instalado quase sempre; `htop` precisa instalação, mas é mais legível. |
| `sudo renice -n 10 -p 1234` | Reduzir a prioridade de uma tarefa de segundo plano já em execução. | Escala de `nice` vai de -20 (mais prioridade) a +19 (menos); `nice` define no início, `renice` altera depois. |
| `ps aux \| grep ' Z '` | Limpar zumbis remanescentes após falha de uma aplicação. | Um zumbi já terminou, mas o pai não leu seu código de saída; um órfão é diferente, seu pai morreu e o `init`/`systemd` o adota sem virar zumbi. O único remédio para um zumbi é o pai ler o código de saída, ou matar o próprio pai. |
| `command &` / `jobs` / `fg %1` / `bg %1` | Rodar múltiplos comandos sem bloquear o terminal atual. | `Ctrl+Z` pausa o processo em primeiro plano; `bg` o retoma em segundo plano de onde parou. |

## Discos e volumes

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `lsblk --output NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE` | Ver discos e partições reconhecidos pelo kernel antes de particionar ou localizar uma montagem. | Um dispositivo sem `MOUNTPOINT` não está montado, não necessariamente vazio; o nome (`/dev/sdb`) pode variar entre boots em hosts com múltiplos discos. |
| `blkid /dev/sdb1` | Confirmar se um dispositivo já tem filesystem, e obter o UUID para referenciá-lo de forma estável. | `PARTUUID` identifica a partição, `UUID` identifica o filesystem dentro dela; os dois mudam se o filesystem for recriado. Referenciar por `UUID=` em `/etc/fstab` evita apontar para o disco errado quando a ordem de detecção muda. |
| `smartctl -a /dev/sda` | Investigar suspeita de falha de disco antes de virar perda de dados. | Um `PASSED` na autoavaliação reflete o firmware do disco, não é garantia; `Reallocated_Sector_Ct` crescendo é sinal de degradação mesmo com status geral ainda `PASSED`. Num volume replicado (Longhorn ou outro), o disco degradado é o do nó, a réplica correspondente precisa ser tratada no nível do sistema de armazenamento, não só trocando o disco físico. |

## Filesystems

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `df -h` / `du -sh /* \| sort -h` | Diagnosticar disco cheio ou achar o que consome espaço. | `df` mede no nível de filesystem/partição; `du` no nível de diretório e arquivo. |
| `df -i` | Quando o filesystem reporta espaço livre mas recusa criar arquivo novo. | Cada inode representa um arquivo ou diretório; um filesystem pode ficar sem inodes antes de ficar sem espaço em bytes, comum em diretórios com muitos arquivos pequenos (caches, sessões). |
| `sudo mount -t nfs server:/export /mnt/nfs` | Montar armazenamento externo ou um destino de backup pela rede. | `hard` faz o cliente NFS tentar novamente indefinidamente em falha do servidor, em vez de retornar erro; desmonte com `umount` antes de remover fisicamente o dispositivo. |
| `chmod 644\|755 arquivo` | Corrigir permissões ou reforçar restrição de segurança. | Notação octal soma valores (4 leitura, 2 escrita, 1 execução) por dono/grupo/demais; `-R` recursivo aplica a mesma permissão a arquivos e diretórios indiscriminadamente, o que costuma abrir mais acesso do que o necessário. |
| `sudo chown user:group arquivo` | Corrigir propriedade após uma cópia ou ajustar um volume montado em container. | Exige root ou ser o dono atual com permissão de transferir; qualquer um dos dois lados de `usuário:grupo` pode ser omitido. |
| `find /path -name "*.log" -mtime +30` | Limpeza de filesystem, auditoria, localizar logs antigos. | `-delete` remove imediatamente; teste sempre sem `-delete` primeiro para confirmar a lista de resultados antes de acrescentar a remoção. |
| `grep -r "padrão" /path` | Localizar uma configuração, depurar comportamento, auditar arquivos. | `-B`/`-A` mostram contexto antes/depois da ocorrência; `-v` inverte a busca, mostrando o que não contém o padrão. |

## Continue por aqui

[Coreutils](../aprender/sistemas/linux/coreutils.md) e [documentação de comandos](../aprender/sistemas/linux/documentacao.md) cobrem a família de utilitários por trás desses comandos e onde procurar ajuda antes de adivinhar uma flag. [Manutenção de nó: cordon, drain e disco](../operacional/manutencao-de-no-cordon-drain-e-disco.md) explica por que os dois consumidores de disco de um nó de cluster merecem monitoramento separado.
