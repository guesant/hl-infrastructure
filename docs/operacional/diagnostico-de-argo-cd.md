# Argo CD OutOfSync

Argo CD compara continuamente o que está declarado no Git com o que existe no cluster e reporta duas dimensões que não devem ser confundidas.

`OutOfSync` descreve a divergência entre estado desejado e estado observado. Pode ser uma alteração manual no cluster ou uma revisão do Git ainda não sincronizada. `Degraded` descreve a saúde dos recursos sincronizados. Uma Application pode estar sincronizada e ainda assim degradada por `CrashLoopBackOff`, `ImagePullBackOff` ou uma falha de probe.

Uma causa comum de `OutOfSync` permanente é um controller externo escrevendo o mesmo campo que Argo CD reconcilia, como um autoscaler ajustando réplicas. Nesse caso, documente a propriedade do campo e configure a diferença esperada apenas quando a alteração externa for realmente legítima.

Depois de corrigir a causa, uma nova sincronização aplica o estado desejado. Use operações destrutivas com cuidado quando outro controller gerenciar parte do recurso.

## Relações

- [Argo CD](../aprender/argocd.md) explica sincronização e reconciliação.
- [GitOps](../aprender/entrega/gitops.md) explica o modelo pull-based.
- [Rollout de imagens](../arquitetura/rollout-de-imagens.md) mostra uma decisão do projeto.
