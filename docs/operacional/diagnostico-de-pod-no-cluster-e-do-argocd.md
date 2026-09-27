# Mapa de diagnóstico do cluster

Este mapa separa sintomas que costumam ser investigados juntos, mas possuem recursos, controladores e causas diferentes. Escolha a página conforme o objeto que apresenta o sintoma.

- [Pod Pending](diagnostico-de-pod-pending.md) trata agendamento, requests, taints, afinidade e volumes.
- [Nó NotReady](diagnostico-de-no-notready.md) trata heartbeat, kubelet, pressão do nó e recuperação do host.
- [Certificate não Ready](diagnostico-de-certificate.md) trata a cadeia ACME e os recursos de emissão.
- [Argo CD OutOfSync](diagnostico-de-argo-cd.md) trata diferença entre Git, cluster e saúde da Application.

O procedimento comum é começar pelo recurso que reporta o sintoma, observar eventos recentes e seguir para o controlador responsável. Logs de um container que nem iniciou não substituem os eventos do scheduler, kubelet, cert-manager ou Argo CD.

## Relações

- [Resposta a incidente](resposta-a-incidente.md) organiza a comunicação e a contenção.
- [Manutenção de nó](manutencao-de-no-cordon-drain-e-disco.md) trata intervenções planejadas.
- [Argo CD](../aprender/argocd.md) e [TLS automático](../aprender/tls-automatico.md) explicam os mecanismos usados nos diagnósticos.
