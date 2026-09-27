# Evacuação de nó

`cordon` marca o nó como `SchedulingDisabled`. Nenhum Pod novo é agendado nele, mas os Pods existentes continuam em execução.

`drain` evacua os Pods existentes, respeita `PodDisruptionBudget` quando possível e implica um cordon. Use drain quando a manutenção exige reiniciar o host ou garantir que nada continue rodando nele. Use apenas cordon quando a intenção for impedir novos agendamentos durante uma investigação.

Em cluster de nó único, drain remove todos os workloads sem destino alternativo. Trate essa operação como indisponibilidade planejada. Ao terminar, `uncordon` reabre o agendamento, mas não força Pods pendentes a serem executados se outro requisito continuar inválido.

Se drain recusar um Pod sem controlador, confirme se ele foi criado avulso. Se expirar durante o período de graça, investigue o encerramento antes de reduzir o tempo ou forçar a remoção.

## Relações

- [PodDisruptionBudget](../aprender/kubernetes/recursos/pdb.md) explica interrupções voluntárias.
- [Graceful shutdown](../aprender/kubernetes/recursos/graceful-shutdown.md) explica encerramento ordenado.
