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

## Idiomas de script Bash

Modo estrito, para encerrar um script ao primeiro sinal de problema em vez de continuar silenciosamente:

```bash
set -euo pipefail
trap 'echo "Error on line $LINENO"' ERR
```

| Flag | Efeito |
| --- | --- |
| `-e` | encerra ao primeiro comando que falha |
| `-u` | trata variável não definida como erro |
| `-o pipefail` | propaga falha de qualquer estágio dentro de um pipe |

Sem `pipefail`, um `comando_que_falha | grep x` só reporta o código de saída do `grep`.

O `trap ERR` acima imprime a linha exata onde o erro ocorreu, útil para localizar a falha num script maior.

Validar que uma variável está definida, ou usar um valor padrão em vez de falhar:

```bash
: "${VAR:?VAR não definido}"

# Ou usando um valor padrão em vez de falhar
: "${VAR:=${DEFAULT}}"
```

A primeira forma garante que a variável está definida e não vazia, falhando de imediato com a mensagem informada; a segunda atribui um valor padrão quando ela estiver vazia, sem interromper a execução.

Loop com nova tentativa (retry) e backoff exponencial:

```bash
for i in {1..5}; do
  if comando; then
    break
  fi
  echo "Tentativa $i falhou, tentando novamente..."
  sleep $((2 ** i))
done
```

Tenta um comando até 5 vezes, aumentando o intervalo entre tentativas de forma exponencial (2s, 4s, 8s, 16s, 32s); útil para operações que podem falhar por condição transitória, como uma chamada de rede.

Limpeza garantida com `trap EXIT`, que dispara tanto numa saída normal quanto numa saída por erro:

```bash
cleanup() {
  rm -rf "$tmpdir"
}
tmpdir=$(mktemp -d)
trap cleanup EXIT
```

Processamento em paralelo, um processo em segundo plano por arquivo, só continuando depois que todos terminarem:

```bash
for file in *.txt; do
  process_file "$file" &
done
wait  # aguarda todos os processos em segundo plano terminarem
```

Isso não limita quantos processos rodam ao mesmo tempo; para um número grande de arquivos, prefira `xargs -P N` (veja a tabela no início desta página) para controlar o paralelismo.

Validação de dependência externa antes do script depender dela:

```bash
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Erro: comando '$1' não encontrado" >&2
    return 1
  }
}

require_command docker
```

Confirma que um comando existe no `PATH`, produzindo um erro claro em vez de uma falha obscura mais adiante na execução.

Manipulação de string sem abrir um subprocesso externo (`sed`, `tr`):

```bash
"${VAR#prefix}"    # remove um prefixo
"${VAR%suffix}"    # remove um sufixo
"${VAR/old/new}"   # substitui um trecho
"${VAR^^}"         # maiúsculas (Bash 4 ou superior)
```

Essas expansões de parâmetro do próprio Bash são mais rápidas e evitam depender de uma ferramenta externa nem sempre disponível.

Saída colorida no terminal:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}OK${NC}"
echo -e "${RED}Erro${NC}"
```

`-e` é necessário para o `echo` interpretar as sequências de escape; um script rodando num pipeline de CI sem terminal interativo às vezes exibe os códigos como texto literal em vez de cor, então trate isso como recurso cosmético, não como parte da lógica do script.

Execução condicional, atalho para evitar um `if` completo quando a condição cabe numa linha:

```bash
output=$(comando)
[[ -n "$output" ]] && echo "Resultado: $output"

# Só executa se o arquivo foi modificado há menos de 1 hora
[[ $(find file -mmin -60) ]] && echo "Recente"
```

## Continue por aqui

[Shells e scripts](../aprender/shells-e-scripts.md) cobre a diferença entre os modos de invocação de um shell e as armadilhas de portabilidade entre `bash` e um `sh` POSIX puro, relevante para vários comandos acima que só existem no Bash.
