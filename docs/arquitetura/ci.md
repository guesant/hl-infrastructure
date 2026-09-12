# A pipeline de CI

O workflow [ci.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/ci.yml) roda em todo push e pull request, com dez jobs em paralelo e um décimo primeiro, `gate`, que depende de todos os outros via `needs:` e falha se qualquer um deles falhar. É esse único job, e não a lista inteira, que faz sentido marcar como check obrigatório na branch protection.

## Os jobs

`actionlint` e `zizmor` auditam os próprios workflows do GitHub Actions, o primeiro por erros de sintaxe e lógica, o segundo por padrões inseguros conhecidos (permissões excessivas, injeção via template, checkout sem `persist-credentials: false`).

`gitleaks` varre todo o histórico do git em busca de segredo commitado por engano. `osv-scanner` e `trivy` (modo `fs`) procuram dependências com vulnerabilidade conhecida; hoje nenhum dos dois encontra nada, porque o repositório não tem manifesto de dependência em nenhum ecossistema que eles entendam, o que é o resultado esperado, não uma falha de cobertura.

`ast-grep` aplica regras estruturais próprias, declaradas em [.config/ast-grep](https://github.com/guesant/hl-infrastructure/tree/main/.config/ast-grep), sobre todo YAML e shell do repositório: todo apply de chart Helm precisa de `--server-side --force-conflicts`, toda task de comando precisa de `changed_when` explícito, e nenhum comentário narrativo é permitido fora de uma diretiva de ferramenta ou do marcador `IMPORTANT:`. `jscpd` reporta duplicação de código entre as roles, sem falhar o build por isso; a duplicação entre as seis roles de instalação de chart é intencional, não um erro a corrigir.

`kube-linter`, `checkov` e `trivy` (modo `config`) primeiro renderizam os sete charts Helm que as roles instalam, depois checam o resultado contra um conjunto restrito de regras (contêiner privilegiado, namespace de rede ou PID do host compartilhado, montagem de diretório sensível do host). O Cilium fica de fora desse conjunto restrito: uma CNI legitimamente precisa desses privilégios para funcionar, e sinalizar isso como problema seria ruído, não sinal.

## Por que um workflow só

Antes desta consolidação, os mesmos dez jobs viviam espalhados em quatro arquivos de workflow diferentes. Isolar por arquivo fazia sentido enquanto cada grupo tinha um gatilho genuinamente diferente, mas o resultado prático era dez checks separados para configurar como obrigatórios na branch protection, e nenhum lugar único que respondesse à pergunta "este push está OK para mergear". Um workflow só, com um job `gate` no final, resolve isso sem abrir mão do isolamento por job: cada job continua com seu próprio `permissions:`, e o `gate` não precisa saber nada sobre o que cada ferramenta faz, só se algum `needs` falhou.

O arquivo único concentra `contents: read` no topo, com escopos mais amplos como `security-events: write` declarados job a job, exatamente como antes; a diferença é o arquivo, não o isolamento de permissão.

## Rodando localmente

Cada job tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda o mesmo comando; veja [rodar os quality gates localmente](../operacional/rodar-quality-gates-localmente.md).
