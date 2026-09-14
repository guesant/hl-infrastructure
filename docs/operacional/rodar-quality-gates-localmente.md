# Rodar os quality gates localmente

Todo check que a pipeline de CI roda tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem Docker e roda o mesmo comando, então o resultado local é idêntico ao da CI, nunca uma aproximação.

Para rodar tudo de uma vez, na mesma ordem da CI:

```bash
just check
```

Cada bloco abaixo é um subconjunto disso. Para os workflows do GitHub Actions, o YAML, o Ansible, os scripts de shell, o Dockerfile das ferramentas e a documentação:

```bash
just lint-actions
just lint-yaml
just lint-ansible
just lint-tofu
just lint-shellcheck
just lint-hadolint
just lint-markdown
just lint-prose
just lint-placeholders
just lint-secret-age
just lint-docs
just lint-spelling
```

`lint-placeholders` falha em qualquer valor de exemplo que sobrou no repositório; ele não enxerga dentro dos arquivos cifrados, e para isso existe `just placeholders`, que precisa da sua identidade e por isso não está na CI.

A verificação de links fica fora do `check` e da CI, porque depende de sites externos que falham por conta própria; rode-a à mão quando mexer bastante na documentação:

```bash
just lint-links
```

Para segredos, dependências vulneráveis e vulnerabilidades de sistema de arquivos:

```bash
just security-gitleaks
just security-osv-scanner
just security-trivy-fs
just security-sopssecrets
```

Para as regras estruturais próprias e duplicação de código:

```bash
just quality-ast-grep
just quality-jscpd
```

Para os manifestos Kubernetes que os charts Helm efetivamente instalam:

```bash
just infra-kube-linter
just infra-checkov
just infra-kubeconform
just infra-trivy-config
just infra-helm-lint
```

Nenhum desses comandos precisa de nada instalado na sua máquina além de Docker e do próprio `just`; cada um constrói sua imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda um `docker run` isolado, nunca um binário direto no host. A imagem é taggeada pelo hash do Dockerfile, então o build só acontece de novo quando o Dockerfile muda; `just --list` mostra todas as receitas com uma linha de descrição cada.

## Continue por aqui

Para entender por que esses vinte checks vivem todos dentro de um único workflow de CI, veja [A pipeline de CI](../arquitetura/ci.md) na arquitetura.
