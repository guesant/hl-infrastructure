# Pod Pending

Um Pod em `Pending` significa que o scheduler ainda não encontrou um nó compatível com os requisitos declarados, ou não pôde usar o nó que encontrou.

A seção `Events` ao final de `kubectl describe pod` costuma nomear a causa diretamente:

| Causa reportada em `Events` |
| --- |
| `Insufficient cpu` |
| `Insufficient memory` |
| `node(s) had taint that the pod didn't tolerate` |
| `didn't find available persistent volumes` |

Num cluster de um único nó, "nenhum nó disponível" quase sempre significa que esse nó específico não atende a algum requisito. Verifique:

- `requests` de CPU ou memória maiores que a capacidade livre em `kubectl describe node`;
- taint no nó sem a toleration correspondente;
- `nodeSelector` ou afinidade que não bate com as labels;
- `PersistentVolumeClaim` pendente por falta de `StorageClass` ou capacidade.

Corrija o requisito identificado, em vez de reaplicar o mesmo manifesto. Um Pod pode ficar pendente com uso de CPU baixo quando os requests já reservaram quase toda a capacidade alocável.

## Relações

- [Requests e limits](../aprender/kubernetes/recursos/requests.md) explica reserva e limite.
- [Taints e tolerations](../aprender/kubernetes/scheduling/taints-tolerations.md) explica restrições de agendamento.
- [PersistentVolumeClaim](../aprender/kubernetes/storage/persistent-volume-claim.md) explica a solicitação de armazenamento.
