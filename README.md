# hl-infrastructure

[![renovate](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![lint-actions](https://github.com/guesant/hl-infrastructure/actions/workflows/lint-actions.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/lint-actions.yml)
[![renovate dependency dashboard](https://img.shields.io/badge/renovate-dependency%20dashboard-1a1f6c.svg)](https://github.com/guesant/hl-infrastructure/issues/3)

Bootstrap único via Ansible e estado contínuo via GitOps para o cluster k3s do homelab. Este repositório nasceu em 2026-09-12, migrado do blog (`guesant/blog`, pasta `deploy/ansible/`); o histórico de decisões anterior a essa data continua em `docs/pendencias-e-decisoes.md`, no repositório do blog.

## Ansible

A pasta `ansible/` provisiona o nó do zero: cgroups, hardening de sistema operacional (atualizações automáticas, sysctl, auditd, SSH, fail2ban), k3s sem Traefik nem ServiceLB e sem o CNI padrão, Cilium, o operador CloudNativePG, cert-manager, o plugin de backup Barman Cloud do CNPG, o próprio ArgoCD, o controlador de Sealed Secrets e o Argo CD Image Updater.

Antes de rodar pela primeira vez, copie os dois arquivos de exemplo e preencha com os dados reais do host:

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
cp ansible/group_vars/all.example.yml ansible/group_vars/all.yml
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

## GitOps

A pasta `argocd/` segue o padrão de app-of-apps recursivo. Dentro dela, `root/` é aplicada uma única vez pela role `bootstrap-app` e contém dois projetos do Argo: um para a infraestrutura definida diretamente neste repositório, com acesso amplo a recursos de cluster, e outro para satélites, restrito a recursos de namespace, com uma única exceção liberada explicitamente (o tipo StorageClass, já que o chart do Postgres declara uma). A partir daí, uma aplicação raiz sincroniza sozinha tudo que existir dentro de `argocd/applications/`.

Hoje só existe um satélite ali: uma aplicação apontando para a pasta de deploy do próprio blog, no repositório `guesant/blog`, com sincronização recursiva de diretório ligada. Isso significa que o Argo acompanha sozinho tudo que esse diretório contiver, sem exigir nenhum passo manual daqui. Um commit no repositório do blog já basta para propagar; o Ansible deste repositório nunca precisa rodar de novo só por causa disso.

Um satélite novo (outro repositório de aplicação) entra como mais um arquivo dentro de `argocd/applications/`, seguindo o mesmo formato do satélite do blog.

## CI

Dois workflows cuidam da própria manutenção do repositório: `renovate.yml` roda o Renovate self-hosted todo dia de manhã, isolado num environment restrito à branch main, e sabe re-baixar o manifesto oficial inteiro de cada componente vendorizado quando a versão sobe, não só trocar a tag da imagem; `lint-actions.yml` audita os próprios workflows com actionlint e zizmor sempre que algo muda em `.github/workflows/`. A receita `just lint-actions` roda os dois localmente, lendo a mesma versão pinada que o workflow usa, então nunca há duas versões divergentes pra lembrar de manter sincronizadas.
