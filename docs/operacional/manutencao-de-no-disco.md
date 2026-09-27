# Pressão de disco

O disco de um nó pode ser consumido por imagens e camadas do runtime, logs, snapshots e pelo datastore do cluster quando o control plane também está no host. Verifique cada caminho separadamente antes de atribuir a causa a um workload.

Quando o espaço cai abaixo do limiar, o kubelet reporta `DiskPressure` e pode evictar Pods de prioridade mais baixa. Isso é diferente de um alerta preventivo de espaço baixo. O runtime pode remover imagens órfãs, mas depender apenas dessa limpeza reativa mantém o nó próximo do limite.

Monitore retenção de logs, snapshots do datastore, imagens não usadas e crescimento de volumes. Uma limpeza proativa deve ter lista explícita de alvos e não pode remover volumes ou snapshots necessários para recuperação.

## Relações

- [Datastore do K3s](../aprender/kubernetes/control-plane/datastore.md) explica o consumidor de disco do control plane.
- [Backup](../aprender/confiabilidade/backup/backup.md) explica por que limpeza não substitui cópia recuperável.
