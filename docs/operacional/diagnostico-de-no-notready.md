# Nó NotReady

Um nó `NotReady` deixou de reportar heartbeats saudáveis ao control plane. Em um cluster de nó único, isso equivale à indisponibilidade do cluster inteiro e merece tratamento de incidente.

`kubectl describe node` expõe a condição específica na seção `Conditions`:

| Condição | O que indica |
| --- | --- |
| `MemoryPressure`, `DiskPressure`, `PIDPressure` | pressão no consumidor correspondente |
| `Ready: Unknown` | perda de comunicação entre control plane e kubelet |

Quando control plane e kubelet rodam no mesmo host, a perda de comunicação normalmente aponta para o serviço parado, o host travado ou pressão local. Confira o status do serviço e os logs do boot atual e anterior. Um relógio desalinhado também pode afetar heartbeats e validações TLS.

Se o host inteiro não voltar por perda de hardware ou corrupção de disco, a resposta deixa de ser reiniciar o serviço e passa a ser reconstruir o cluster a partir da automação de disaster recovery testada.

## Relações

- [Pressão de disco](manutencao-de-no-disco.md) trata eviction e consumidores de espaço.
- [Manutenção de nó](manutencao-de-no-cordon-drain-e-disco.md) trata cordon e drain planejados.
- [Datastore do K3s](../aprender/kubernetes/control-plane/datastore.md) explica o armazenamento local do control plane.
