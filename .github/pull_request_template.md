## O que muda

## Checklist

- [ ] `just check` passou localmente.
- [ ] Nenhuma credencial, chave ou kubeconfig foi adicionada; segredos novos entram só como `SopsSecret` ou em `ansible/group_vars/all/secrets.yml`.
- [ ] Toda imagem, action, chart e binário novo está pinado por versão, digest ou SHA.
- [ ] A documentação em `docs/` reflete a mudança, sem framing histórico.
- [ ] Se a mudança toca privilégio, exposição de rede ou permissão do Argo, o impacto está descrito acima.
