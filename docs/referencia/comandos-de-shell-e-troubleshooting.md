# Comandos de shell e troubleshooting genérico

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `!!` / `sudo !!` / `!123` | Repetir o último comando, ou executá-lo de novo com privilégios elevados. | Expansão de histórico pode ter efeitos inesperados dentro de scripts; desabilite com `set +H` quando necessário. |
| `history \| grep ssh` | Encontrar um comando executado anteriormente. | `history -c` limpa só a memória da sessão atual, não o arquivo `~/.bash_history` já salvo em disco. |
| `command > out.txt 2>&1` | Capturar logs de um comando ou silenciar sua saída. | A ordem importa: `> file 2>&1` primeiro aponta stdout para o arquivo, depois aponta stderr para onde stdout já está; `2>&1 > file` não produz o mesmo resultado. `&>` é atalho do Bash, não portável para `sh` puro. |
| `command1 \| command2` / `command \| tee file \| less` | Encadear transformações de dados ou filtrar saída. | `tee` grava num arquivo e repassa ao mesmo tempo para o próximo comando do pipe; `xargs` converte linhas da entrada padrão em argumentos de linha de comando, para quando o próximo comando não lê stdin diretamente. |
| `command1 && command2` / `command1 \|\| command2` | Encadeamento condicional simples, sem um bloco `if` completo. | `&&` roda o segundo só se o primeiro tiver sucesso; `\|\|` roda o segundo só se o primeiro falhar; código de saída `0` é sucesso por convenção, qualquer outro valor indica erro. |
| `time command` / `/usr/bin/time -v command` | Medir desempenho ou diagnosticar lentidão. | `time` (builtin do shell) mostra tempo real, de CPU em modo usuário e em modo kernel; `/usr/bin/time -v` é um binário separado, com métricas adicionais como pico de memória residente, pode não vir instalado por padrão. |
| `diff <(command1) <(command2)` | Comparar o estado antes e depois de uma mudança, ou dois ambientes. | `<(...)` é process substitution, específico do Bash, trata a saída de um comando como se fosse um arquivo; `comm -3 <(sort a) <(sort b)` mostra só as diferenças entre duas entradas já ordenadas. |
| `seq 1 100 \| xargs -P 4 -I {} curl "...{}"` | Acelerar tarefas independentes entre si (testes, downloads em lote). | `xargs -P N` limita a no máximo N processos simultâneos e já vem com qualquer coreutils; `parallel` tem sintaxe mais rica mas exige instalação separada. Paralelizar contra uma API externa sem respeitar limite de taxa pode ser interpretado como abuso e resultar em bloqueio. |

## Continue por aqui

[Shells e scripts](../aprender/shells-e-scripts.md) cobre a diferença entre os modos de invocação de um shell e as armadilhas de portabilidade entre `bash` e um `sh` POSIX puro, relevante para vários comandos acima que só existem no Bash.
