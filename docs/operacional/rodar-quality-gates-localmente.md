# Rodar os quality gates localmente

Todo check que a pipeline de CI roda tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem Docker e roda o mesmo comando, então o resultado local é idêntico ao da CI, nunca uma aproximação.

Para rodar tudo de uma vez, na mesma ordem da CI:

```bash
just check
```

Cada bloco abaixo é um subconjunto disso. Para os workflows do GitHub Actions, o YAML, o Ansible, o OpenTofu, os scripts de shell, o Dockerfile das ferramentas, a política de Pod Security dos namespaces e a documentação:

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

`lint-tofu` roda `fmt` e `validate` sobre o código do OpenTofu; `infra-conftest` vai além e confere as políticas próprias deste repositório sobre o mesmo código, com o Conftest. `lint-placeholders` falha em qualquer valor de exemplo que sobrou no repositório; ele não enxerga dentro dos arquivos cifrados, e para isso existe `just placeholders`, que precisa da sua identidade e por isso não está na CI.

Para as mensagens de commit que ainda não foram enviadas para `main`:

```bash
just lint-commits
```

Sem argumentos, ele compara `origin/main` com `HEAD`; passe uma origem e um destino diferentes quando quiser conferir outro intervalo.

A verificação de links fica fora do `check` e da CI, porque depende de sites externos que falham por conta própria; rode-a à mão quando mexer bastante na documentação:

```bash
just lint-links
```

Para segredos, dependências vulneráveis, vulnerabilidades de sistema de arquivos e vulnerabilidades nas imagens que o cluster efetivamente roda:

```bash
just security-gitleaks
just security-osv-scanner
just security-trivy-fs
just security-sopssecrets
just security-trivy-images
```

`security-trivy-images` falha numa CVE crítica corrigível em qualquer imagem implantada, e grava, como efeito colateral sempre útil de conferir depois, um SBOM em formato CycloneDX por imagem em `.build/sbom/`.

Para as regras estruturais próprias e duplicação de código:

```bash
just quality-ast-grep
just quality-jscpd
```

`quality-jscpd` é só informativo, nunca falha o gate; o relatório de duplicação que ele produz fica em `.build/jscpd-report/`.

Para os manifestos Kubernetes que os charts Helm efetivamente instalam, depois de renderizados como em [Renderizar os charts localmente](renderizar-charts-localmente.md):

```bash
just infra-kube-linter
just infra-checkov
just infra-kubeconform
just infra-trivy-config
just infra-kubescape
just infra-helm-lint
```

Os cinco primeiros recebem esses manifestos já renderizados em `.build/rendered/`, que a própria receita gera antes de rodar; `infra-helm-lint` é diferente, roda `helm lint` direto sobre o código-fonte dos charts wrapper locais, sem depender de renderização nenhuma.

Para conferir que o site de documentação constrói sem aviso, o mesmo que a CI publica:

```bash
just docs-build
```

O resultado fica em `.build/site/`, fora do git.

Nenhum desses comandos precisa de nada instalado na sua máquina além de Docker e do próprio `just`; cada um constrói sua imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda um `docker run` isolado, nunca um binário direto no host. A imagem é taggeada pelo hash do Dockerfile, então o build só acontece de novo quando o Dockerfile muda; `just --list` mostra todas as receitas com uma linha de descrição cada.

## Continue por aqui

Para entender por que os checks listados na receita `check` do [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) vivem todos dentro de um único workflow de CI, veja [A pipeline de CI](../arquitetura/ci.md) na arquitetura.
