# Rodar os quality gates localmente

Todo check que a pipeline de CI roda tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem Docker e roda o mesmo comando, então o resultado local é idêntico ao da CI, nunca uma aproximação.

Para os workflows do GitHub Actions:

```bash
just lint-actions
```

Para segredos, dependências vulneráveis e vulnerabilidades de sistema de arquivos:

```bash
just security-gitleaks
just security-osv-scanner
just security-trivy-fs
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
just infra-trivy-config
```

Nenhum desses comandos precisa de nada instalado na sua máquina além de Docker e do próprio `just`; cada um constrói sua imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda um `docker run` isolado, nunca um binário direto no host.

## Continue por aqui

Para entender por que esses nove checks vivem todos dentro de um único workflow de CI, veja [A pipeline de CI](../arquitetura/ci.md) na arquitetura.
