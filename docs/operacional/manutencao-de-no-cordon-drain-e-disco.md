# Mapa de manutenção de nó

Escolha o procedimento conforme o efeito que a manutenção precisa produzir:

- [Cordon e drain](manutencao-de-no-cordon-drain.md) interrompe ou impede agendamento de workloads.
- [Quorum de control plane](manutencao-de-no-quorum.md) define quantos servidores podem sair simultaneamente.
- [Pressão de disco](manutencao-de-no-disco.md) trata eviction, imagens, logs e datastore.

Manutenção planejada deve ser distinguida de diagnóstico de falha. O [diagnóstico de nó NotReady](diagnostico-de-no-notready.md) começa por condições e heartbeats; este mapa começa por uma intervenção conhecida.
