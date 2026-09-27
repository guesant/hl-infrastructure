# Mapa de reconstrução de cluster e recuperação de segredos

Um cluster de nó único pode exigir duas decisões independentes depois da perda do host: escolher como reconstruir o estado do cluster e recuperar o material que permite decifrar ou sincronizar segredos. Essas decisões não devem ser confundidas, porque uma restauração do datastore não substitui a recuperação das chaves externas.

## Reconstruir o cluster

O cluster pode ser restaurado pelo snapshot do datastore ou reconstruído a partir do GitOps. O primeiro preserva o estado observado no momento do snapshot. O segundo reproduz somente o estado declarado no repositório.

Consulte [Reconstruir um cluster de nó único](reconstrucao-de-cluster-single-node.md) para os critérios, o RPO e os limites de cada estratégia.

## Recuperar segredos

A capacidade de decifrar arquivos SOPS, autenticar em um backend externo ou destravar um cofre possui material crítico próprio. Ela precisa ser validada separadamente da restauração do cluster.

Consulte [Recuperar a capacidade de decifrar segredos](recuperacao-de-segredos.md) para identificar esse material e testar a recuperação.

## Recuperar dados persistentes

Volumes persistentes não voltam automaticamente em nenhuma das estratégias. A recuperação dos dados segue o backup específico do serviço, separado da reconstrução do cluster e da recuperação das chaves.

[Restaurar o node do zero](restaurar-o-node.md) reúne a sequência operacional adotada neste repositório.
