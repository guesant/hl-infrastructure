## O que muda

## Checklist

- [ ] Os quality gates passaram localmente (`just lint-actions`, `just quality-ast-grep`, `just infra-kube-linter`, `just infra-kubeconform`, `just docs-build`).
- [ ] Nenhuma credencial, chave ou kubeconfig foi adicionada; segredos novos entram só como `SealedSecret` ou em `ansible/group_vars/all/secrets.yml`.
- [ ] Toda imagem, action, chart e binário novo está pinado por versão, digest ou SHA.
- [ ] A documentação em `docs/` reflete a mudança, sem framing histórico.
- [ ] Se a mudança toca privilégio, exposição de rede ou permissão do Argo, o impacto está descrito acima.
