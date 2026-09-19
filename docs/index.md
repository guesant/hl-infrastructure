# hl-infrastructure

Este site documenta o hl-infrastructure, o repositório que provisiona e mantém o cluster k3s do homelab. O bootstrap é feito uma única vez via Ansible, direto por SSH no nó, e o estado do cluster depois disso é mantido continuamente via GitOps através do ArgoCD.

A documentação está dividida em partes, cada uma respondendo a uma pergunta diferente. O [Aprender](aprender/index.md) ensina, de forma independente deste repositório, o que é cada ferramenta e conceito que ele usa (Ansible, k3s, GitOps, TLS automático, scanning de vulnerabilidade, entre outros).

A [arquitetura](arquitetura/index.md) explica como o sistema inteiro se encaixa e como cada peça individual (as roles do Ansible, os charts Helm, o padrão de GitOps, a pipeline de CI) funciona e por que foi desenhada daquele jeito, neste cluster específico. O [operacional](operacional/index.md) cobre a rotina de quem já conhece o repositório: implantar, manter e resolver tarefas do dia a dia, incluindo o passo a passo do primeiro bootstrap. A [referência](referencia/index.md) traz a sintaxe exata de um comando ou catálogo externo, para quem já conhece o conceito e só precisa lembrar a forma certa.

Se você está mexendo pela primeira vez neste repositório, comece pelo [primeiro bootstrap](operacional/primeiro-bootstrap.md); se alguma ferramenta que ele instala for nova para você, veja o conceito correspondente em [Aprender](aprender/index.md) antes. Se você já tem o ambiente rodando e só precisa lembrar como fazer algo específico, vá direto ao [operacional](operacional/index.md). Se você quer entender por que uma peça é do jeito que é antes de mexer nela, comece pela [arquitetura](arquitetura/index.md).

A seção [contribuindo](contribuindo/index.md) explica como esta documentação em si é organizada e escrita, para quem for adicionar ou editar uma página.

## Continue por aqui

[Primeiro bootstrap](operacional/primeiro-bootstrap.md) é o ponto de partida prático; [contribuindo](contribuindo/index.md) explica como esta documentação em si é escrita.
