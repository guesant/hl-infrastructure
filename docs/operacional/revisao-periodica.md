# Revisão periódica de permissões e exposição

Os gates de CI conferem o que está no git, mas não enxergam o que mudou fora dele nem o que ficou velho sem ninguém notar: uma porta que alguém abriu à mão no firewall, um token com permissão demais, uma `ClusterRole` que um chart novo trouxe. Esta revisão existe para isso, e o prazo dela é declarado em [.config/security-review.conf](https://github.com/guesant/hl-infrastructure/blob/main/.config/security-review.conf). O job `secret-age` da CI avisa num push quando a última revisão passou do prazo e falha na execução agendada, então a revisão não depende de alguém lembrar.

## O que conferir

A revisão é uma leitura, não uma mudança. Cada achado vira uma linha no [checklist de segurança](../arquitetura/checklist-de-seguranca.md) ou uma correção no repositório, e só então a data é atualizada.

1. Exposição do node: `firewall-cmd --permanent --list-all-zones` no Pi deve mostrar só o que a role `firewall` declara. A reconciliação da role remove o resto, mas um item novo que ela recuse remover por passar do teto aparece aqui primeiro.
2. Serviços escutando: `ss -tulnp` no Pi, procurando qualquer processo novo fora do k3s, do Cilium e do SSH.
3. Contas e chaves: `awk -F: '$2 !~ /^[!*]/' /etc/shadow` não deve listar ninguém, e `/root/.ssh/authorized_keys` deve ter só a chave do operador.
4. RBAC do cluster: as `ClusterRole` com curinga em verbos, recursos ou grupos de API, comparadas com as justificadas no checklist; qualquer uma nova precisa de justificativa ou de correção.
5. Tokens externos: as permissões do API token da Cloudflare, do token do Renovate e das chaves age em `.sops.yaml`, conferidas contra o que cada uma precisa.
6. Resultado do kube-bench e do kubescape: as falhas novas desde a última revisão.
7. Deriva do que vive fora do cluster: `just tofu <módulo> plan` para `cloudflare`, `tailscale`, `keycloak-master`, `keycloak-homelab` e `keycloak-management`; qualquer mudança que apareça foi feita à mão no console e precisa voltar ao git ou ser desfeita pelo `apply`. No mesmo espírito, `just bootstrap --check -e chart_reconcile=true` força as roles `cilium` e `argocd` a comparar o chart com o cluster, o que o atalho por hash não faz.
8. Usuários do Keycloak: no console, os usuários de cada realm e os papéis do `master`; quem não deveria mais entrar sai dali, e o `admin` do módulo é rotacionado com `just keycloak-rotate-admin` se a data do `keycloak-master.sops.env` passou do prazo em `.config/secret-max-age.conf`.

## Registrar a revisão

Depois de conferir, atualize `last_review` em `.config/security-review.conf` com a data do dia e commite junto com o que a revisão tiver mudado.
