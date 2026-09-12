# A pipeline de CI

Três workflows automatizam a manutenção deste repositório. O [renovate.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/renovate.yml) roda self-hosted todo dia de manhã, isolado num environment restrito à branch principal, e bumpa a versão de cada chart Helm diretamente em `ansible/group_vars/all.example.yml`. O [docs.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/docs.yml) constrói este site com MkDocs a cada push e publica no GitHub Pages quando o push é em main; em pull requests, ele só constrói com `--strict`, para pegar link quebrado ou página fora da navegação, sem publicar nada. O restante, cobertura de segurança, qualidade estrutural e lint de infraestrutura, vive no [ci.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/ci.yml), detalhado no resto desta página.

O `ci` roda em todo push em `main` e em todo pull request, com onze jobs em paralelo e um décimo segundo, `gate`, que depende de todos os outros via `needs:` e falha se qualquer um deles falhar. É esse único job, e não a lista inteira, que faz sentido marcar como check obrigatório na branch protection.

## Os jobs

`actionlint` e `zizmor` auditam os próprios workflows do GitHub Actions, o primeiro por erros de sintaxe e lógica, o segundo por padrões inseguros conhecidos (permissões excessivas, injeção via template, checkout sem `persist-credentials: false`).

`gitleaks` varre todo o histórico do git em busca de segredo commitado por engano. `osv-scanner` e `trivy` (modo `fs`) procuram dependências com vulnerabilidade conhecida; hoje nenhum dos dois encontra nada, porque o repositório não tem manifesto de dependência em nenhum ecossistema que eles entendam, o que é o resultado esperado, não uma falha de cobertura.

`ast-grep` aplica regras estruturais próprias, declaradas em [.config/ast-grep](https://github.com/guesant/hl-infrastructure/tree/main/.config/ast-grep), sobre todo YAML e shell do repositório: todo apply de chart Helm precisa de `--server-side --force-conflicts`, toda task de comando precisa de `changed_when` explícito, e nenhum comentário narrativo é permitido fora de uma diretiva de ferramenta ou do marcador `IMPORTANT:`. `jscpd` reporta duplicação de código entre as roles, sem falhar o build por isso; a duplicação entre as seis roles de instalação de chart é intencional, não um erro a corrigir.

`kube-linter`, `checkov` e `trivy` (modo `config`) primeiro renderizam os sete charts Helm que as roles instalam, depois checam o resultado contra um conjunto restrito de regras (contêiner privilegiado, namespace de rede ou PID do host compartilhado, montagem de diretório sensível do host). O Cilium fica de fora desse conjunto restrito: uma CNI legitimamente precisa desses privilégios para funcionar, e sinalizar isso como problema seria ruído, não sinal.

`kubeconform` valida os mesmos manifestos renderizados, mais tudo em `argocd/`, contra o schema da API do Kubernetes e contra o catálogo público de schemas de CRDs, em modo estrito: um campo com nome errado num `Application` ou num `Cluster` do CloudNativePG falha aqui, antes de chegar ao Argo, em vez de ser silenciosamente ignorado pelo apply. Um schema que não existe no catálogo é pulado, não tratado como erro, para que uma CRD nova não bloqueie o gate. O mesmo job termina com um check próprio, em [.tools/check-images-pinned.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-images-pinned.sh), que falha se qualquer `image:` renderizada vier sem tag nem digest: uma imagem sem tag resolve para `latest` no pull e muda sem deixar rastro no git.

## Por que um workflow só

Onze checks separados exigiriam onze entradas na branch protection e nenhum lugar único que respondesse à pergunta "este push está OK para mergear". Um workflow só, com um job `gate` no final, resolve isso sem abrir mão de isolamento por job: cada job mantém seu próprio `permissions:` (`contents: read` no topo do arquivo, escopos mais amplos como `security-events: write` só onde o job precisa), e o `gate` não precisa saber nada sobre o que cada ferramenta faz, só se algum `needs` falhou. É esse único job que faz sentido marcar como obrigatório na branch protection, em vez da lista inteira.

## Rodando localmente

Cada job tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda o mesmo comando; veja [rodar os quality gates localmente](../operacional/rodar-quality-gates-localmente.md).
