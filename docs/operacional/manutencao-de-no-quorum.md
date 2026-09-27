# Quorum de control plane

Em um cluster com vários servidores de control plane, retirar um servidor temporariamente também o retira do consenso. Com três servidores, o quorum é dois e um único servidor pode ser drenado por vez. Remover um segundo antes de reintegrar o primeiro deixa apenas um membro, que é minoria e não consegue confirmar novas escritas.

Com cinco servidores, o quorum é três e até dois podem ficar indisponíveis simultaneamente. A regra é reintegrar e validar cada servidor antes de retirar o próximo, salvo quando a operação foi planejada para tolerar a perda maior.

Agentes de workload não ameaçam o quorum diretamente, mas a perda simultânea reduz capacidade de agendamento e pode causar pressão de recursos.

## Relações

- [Quorum](../aprender/kubernetes/control-plane/quorum.md) explica a aritmética.
- [Alta disponibilidade](../aprender/kubernetes/arquitetura/ha-multizona.md) explica topologias.
