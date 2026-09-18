# Rodar os quality gates localmente

Todo check que a pipeline de CI roda tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem Docker e roda o mesmo comando, então o resultado local é idêntico ao da CI, nunca uma aproximação. A diferença entre os dois lados está na cobertura, não no critério: a CI quebra os checks em jobs paralelos e pula os que não têm relação com o que mudou, guiada por um filtro de caminhos, enquanto localmente tudo roda em sequência e nada é pulado. Rodar antes de abrir o pull request troca a espera pela fila do GitHub por alguns minutos de CPU na sua máquina.

A receita `check` encadeia todas as outras como dependências do just, na mesma ordem em que a CI as declara, e aborta no primeiro check que falhar, sem chegar aos seguintes. Numa máquina que ainda não rodou nada, a primeira execução é lenta, porque constrói uma imagem por ferramenta antes de começar a checar. Para rodar tudo de uma vez:

```bash
just check
```

Cada bloco abaixo é um subconjunto disso, e rodar só o bloco que cobre a área em que você mexeu é o mesmo recorte que a CI faz sozinha pelo filtro de caminhos. Nenhum check deste bloco decifra nada nem fala com o cluster; todos trabalham sobre o texto commitado. Para os workflows do GitHub Actions, o YAML, o Ansible, o OpenTofu, os scripts de shell, o Dockerfile das ferramentas, a política de Pod Security dos namespaces e a documentação:

```bash
just lint-actions
just lint-yaml
just lint-ansible
just lint-tofu
just infra-conftest
just lint-shellcheck
just lint-hadolint
just lint-markdown
just lint-prose
just lint-placeholders
just lint-secret-age
just lint-pod-security
just lint-docs
just lint-spelling
```

`lint-tofu` roda `fmt` e `validate` sobre o código do OpenTofu; `infra-conftest` vai além e confere as políticas próprias deste repositório sobre o mesmo código, com o Conftest. `lint-placeholders` falha em qualquer valor de exemplo que sobrou no repositório, dos `REPLACE_WITH_` aos domínios terminados em `.invalid`, e de quebra compara o hostname do blog declarado no OpenTofu com o que o chart do blog publica, porque os dois divergirem em silêncio deixa o túnel apontando para um nome que ninguém serve. Ele não enxerga dentro dos arquivos cifrados, e para isso existe `just placeholders`, que precisa da sua identidade e por isso não está na CI. Já `lint-docs` não olha o texto das páginas: ele compara a data do último commit de cada página que declara um marcador `source-of-trust` com a dos arquivos que a página promete descrever, e falha quando a fonte andou depois da revisão.

Uma mensagem fora do padrão só aparece depois do push se ninguém conferir antes, e `just hooks` aponta o git para o hook de `commit-msg` versionado em `.config/githooks`, que roda o mesmo commitlint na hora de escrever a mensagem. Para conferir à mão as mensagens que ainda não foram enviadas para `main`:

```bash
just lint-commits
```

Sem argumentos, ele compara `origin/main` com `HEAD`; passe uma origem e um destino diferentes quando quiser conferir outro intervalo. Cada commit do intervalo vai ao commitlint separadamente e a recipe segue até o fim antes de falhar, então uma execução lista todas as mensagens ruins de uma vez em vez de parar na primeira. Commits de merge ficam de fora da conta.

A verificação de links fica fora do `check` e da CI, porque depende de sites externos que falham por conta própria; rode-a à mão quando mexer bastante na documentação. Ela não é só sobre a internet: o lychee reescreve os links deste repositório no GitHub para os arquivos locais antes de seguir, então um arquivo renomeado ou movido aparece ali como link quebrado, que é a falha que de fato acontece.

```bash
just lint-links
```

Para segredos, dependências vulneráveis, vulnerabilidades de sistema de arquivos e vulnerabilidades nas imagens que o cluster efetivamente roda, o bloco é outro. `security-gitleaks` varre o histórico inteiro do git, e não só a árvore de trabalho, porque um segredo apagado num commit posterior continua recuperável por quem clonar o repositório. `security-sopssecrets` fecha o outro lado disso, conferindo que nenhum `SopsSecret` foi commitado em texto claro e que os destinatários de cada arquivo cifrado batem com `.sops.yaml`.

```bash
just security-gitleaks
just security-osv-scanner
just security-trivy-fs
just security-sopssecrets
just security-trivy-images
```

`security-trivy-images` falha numa CVE crítica corrigível em qualquer imagem implantada, e grava, como efeito colateral sempre útil de conferir depois, um SBOM em formato CycloneDX por imagem em `.build/sbom/`. A lista de imagens sai dos charts já renderizados, então ela é o que o cluster realmente roda, e não o que algum `values.yaml` mencionou um dia. Uma CVE sem correção publicada não derruba o gate, e uma exceção deliberada vai para `.trivyignore.yaml` com justificativa e data de validade, para ela ser revista em vez de virar permanente.

As regras estruturais próprias são as que nenhum linter de ferramenta conhece, porque valem para este repositório e não para a linguagem; `quality-ast-grep` aplica as de `.config/ast-grep` e, junto com elas, o check que recusa comentário narrativo no Dockerfile das ferramentas. Elas rodam ao lado do relatório de duplicação de código:

```bash
just quality-ast-grep
just quality-jscpd
```

`quality-jscpd` é só informativo, nunca falha o gate; o relatório de duplicação que ele produz fica em `.build/jscpd-report/`. Repetição aqui costuma ser legítima, porque charts wrapper e roles do Ansible têm estrutura parecida por natureza, e zerar o número exigiria abstrações piores do que o problema. O relatório serve para notar quando a repetição deixou de ser estrutura e virou um bloco grande copiado, e ele continua dentro do `check` justamente para esse número aparecer sem ninguém precisar lembrar de pedir.

Os checks de manifesto não leem os charts, leem a saída deles, porque um `Deployment` só ganha os campos que o gate cobra depois que o Helm resolve values, templates e os charts dos quais ele depende. Isso também vale para os recursos customizados dos operadores, cujos schemas o `infra-kubeconform` busca no catálogo público de CRDs, já que eles não fazem parte do schema padrão do Kubernetes. Para os manifestos Kubernetes que os charts efetivamente instalam, depois de renderizados como em [Renderizar os charts localmente](renderizar-charts-localmente.md):

```bash
just infra-kube-linter
just infra-checkov
just infra-kubeconform
just infra-trivy-config
just infra-kubescape
just infra-helm-lint
```

Os primeiros recebem esses manifestos já renderizados em `.build/rendered/`, que a própria receita gera antes de rodar; `infra-helm-lint` é diferente, roda `helm lint` direto sobre o código-fonte dos charts wrapper locais, sem depender de renderização nenhuma. A renderização apaga e refaz `.build/rendered/` a cada execução, e antes de renderizar qualquer coisa confere o sha256 dos charts do Argo CD e do Cilium baixados dos repositórios upstream contra o digest declarado em `versions.yml`, de modo que uma versão republicada com conteúdo diferente derruba o gate em vez de passar despercebida. O `cilium.yaml` fica de fora da maior parte desses checks, porque é o chart de um terceiro e o repositório não tem como corrigir o que eles apontariam ali.

O `--strict` do MkDocs transforma em erro o que de outro modo seria aviso, como um link interno para uma página que não existe ou um arquivo que ficou fora do `nav`, e esse é o tipo de coisa que passa batido numa revisão de diff. As dependências do build vêm de `docs/requirements.txt` com hash obrigatório, então o site sai igual em qualquer máquina. Para conferir que ele constrói sem aviso, o mesmo que a CI publica:

```bash
just docs-build
```

O resultado fica em `.build/site/`, fora do git, junto com os relatórios e os manifestos renderizados dos outros gates. `just cleanup` apaga todo esse material recriável e preserva o que não dá para reconstruir, como o inventário, o kubeconfig e as chaves em `.local/operator/`. Para ler o site enquanto escreve, `just docs-serve` sobe o MkDocs em `localhost:8000` com recarga automática.

Nenhum desses comandos precisa de nada instalado na sua máquina além de Docker e do próprio `just`; cada um constrói sua imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda um `docker run` isolado, nunca um binário direto no host. A imagem é taggeada pelo hash do Dockerfile, então o build só acontece de novo quando o Dockerfile muda; `just --list` mostra todas as receitas com uma linha de descrição cada. Atualizar uma ferramenta, então, é mudar uma linha no Dockerfile e deixar a próxima receita reconstruir sozinha, sem ninguém precisar sincronizar versão entre a sua máquina e a CI.

## Continue por aqui

Para entender por que os checks listados na receita `check` do [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) vivem todos dentro de um único workflow de CI, veja [A pipeline de CI](../arquitetura/ci.md) na arquitetura.
