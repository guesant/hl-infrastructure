# Restaurar um volume retido

<!-- source-of-trust paths="argocd/apps/platform/storage argocd/applications/platform/storage.yaml" -->

A única `StorageClass` do cluster, `local-path`, tem `reclaimPolicy: Retain`. Isso muda o que acontece quando um `PersistentVolumeClaim` é apagado: em vez de o provisioner remover o diretório do node, o `PersistentVolume` fica em `Released`, ainda apontando para o diretório em `/var/lib/rancher/k3s/storage/<pv>_<namespace>_<pvc>` e ainda com o `claimRef` do PVC que morreu. O dado está intacto, mas nenhum PVC novo consegue se ligar a esse PV enquanto o `claimRef` antigo estiver lá. Este runbook é o caminho de volta, e vale para o erro comum (um `kubectl delete pvc` ou uma `Application` apagada sem `Delete=false`) e para o caso deliberado de recriar um StatefulSet.

## O que conferir antes

`just kubectl get pv` mostra o PV em `Released` com a coluna `CLAIM` ainda preenchida. Anote o nome do PV e confira no node que o diretório existe e tem o conteúdo esperado (`ls` no caminho do `spec.local.path` ou `spec.hostPath.path` do PV, por SSH). Se o objetivo é descartar o dado, o procedimento é o inverso: apagar o PV (`kubectl delete pv`) e depois o diretório à mão no node, porque com `Retain` o provisioner não faz isso por você.

## Religar o PV a um PVC novo

Primeiro, tire o `claimRef` do PV para ele voltar a `Available`:

```bash
just kubectl patch pv <pv> --type json -p '[{"op":"remove","path":"/spec/claimRef"}]'
```

Depois crie o PVC com o mesmo namespace e o mesmo nome que o consumidor espera, apontando explicitamente para o PV com `volumeName`, mesma classe, mesmo `accessModes` e um `storage` igual ou menor que o do PV:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <nome que o pod espera>
  namespace: <namespace>
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  volumeName: <pv>
  resources:
    requests:
      storage: <tamanho do PV>
```

Com `volumeName`, o Kubernetes liga o PVC a esse PV específico em vez de pedir um novo ao provisioner; o PV volta a `Bound` e o pod que o monta sobe com o dado antigo. Se o PVC é gerenciado pelo Argo (o do Portainer, por exemplo), o manifesto no git é o que deve ser aplicado, e o `volumeName` entra nele só durante a recuperação, saindo depois num commit de limpeza, porque o campo é imutável e o Argo aceitaria a diferença como deriva.

## O caso do CloudNativePG

Um `Cluster` do CNPG cria os PVCs dele com nomes fixos (`<cluster>-1` para o primeiro instance), e o operador espera encontrar o PVC com os labels que ele mesmo põe (`cnpg.io/cluster`, `cnpg.io/instanceName`, `cnpg.io/pvcRole: PG_DATA`). O caminho mais seguro para reaproveitar um volume retido de Postgres é recriar o PVC com esses labels e o `volumeName`, antes de recriar o `Cluster`, e deixar o operador adotá-lo; a alternativa, quando há um backup em object storage, é `bootstrap.recovery`, que não depende do volume. Sem backup fora do node, o volume retido é a única cópia, então confira o diretório antes de qualquer `delete` e nunca apague o PV antes de o novo `Cluster` estar `healthy`.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista o que vive só nos volumes; [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) explica por que a classe é uma só e por que ela é `Retain`.
