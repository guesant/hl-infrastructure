# Contribuindo

Toda mudança entra por branch e pull request contra `main`, passa pelo job `gate` do workflow `ci` e é revisada antes do merge. Para mudanças que alteram o comportamento do cluster (uma role nova, um projeto do Argo, uma política de rede), abra uma issue descrevendo a intenção antes de escrever código.

Antes de abrir a PR, rode localmente o mesmo que a CI roda; nada precisa ser instalado além de Docker e `just`:

```bash
just lint-actions
just security-gitleaks
just quality-ast-grep
just infra-kube-linter
just infra-kubeconform
just docs-build
```

A lista completa está em [rodar os quality gates localmente](https://guesant.github.io/hl-infrastructure/operacional/rodar-quality-gates-localmente/).

Commits seguem Conventional Commits (`tipo(escopo): título`), em inglês, no imperativo, só o título, sem corpo e sem trailer. Nenhum segredo entra no repositório: valores reais ficam em `ansible/group_vars/all.yml`, que é ignorado pelo git, e no cluster só como `SealedSecret`.

As convenções de código (nenhum comentário narrativo) e de escrita da documentação estão em [Contribuindo](https://guesant.github.io/hl-infrastructure/contribuindo/) no site. O projeto adota o [Código de Conduta](CODE_OF_CONDUCT.md) e é licenciado sob GPL-3.0-or-later; ao contribuir, você aceita que sua contribuição seja distribuída sob essa licença.
