# hl-infrastructure

Este site documenta o hl-infrastructure, o repositório que provisiona e mantém o cluster k3s do homelab. O bootstrap é feito uma única vez via Ansible, direto por SSH no nó, e o estado do cluster depois disso é mantido continuamente via GitOps através do ArgoCD.

A documentação está dividida em três partes, cada uma respondendo a uma pergunta diferente. O [tutorial](tutorial/index.md) ensina os conceitos e leva alguém que nunca mexeu neste repositório até um cluster funcionando, passo a passo. A [arquitetura](arquitetura/index.md) explica como o sistema inteiro se encaixa e como cada peça individual (as roles do Ansible, os charts Helm, o padrão de GitOps, a pipeline de CI) funciona e por que foi desenhada daquele jeito. O [operacional](operacional/index.md) cobre a rotina de quem já conhece o repositório: implantar, manter e resolver tarefas do dia a dia.

Se você está mexendo pela primeira vez neste repositório, comece pelo [tutorial](tutorial/primeiro-bootstrap.md). Se você já tem o ambiente rodando e só precisa lembrar como fazer algo específico, vá direto ao [operacional](operacional/index.md). Se você quer entender por que uma peça é do jeito que é antes de mexer nela, comece pela [arquitetura](arquitetura/index.md).

A seção [contribuindo](contribuindo/index.md) explica como esta documentação em si é organizada e escrita, para quem for adicionar ou editar uma página.
