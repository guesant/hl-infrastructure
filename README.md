# hl-infrastructure

[![renovate](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![lint-actions](https://github.com/guesant/hl-infrastructure/actions/workflows/lint-actions.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/lint-actions.yml)
[![renovate dependency dashboard](https://img.shields.io/badge/renovate-dependency%20dashboard-1a1f6c.svg)](https://github.com/guesant/hl-infrastructure/issues/3)

Bootstrap único via Ansible e estado contínuo via GitOps para o cluster k3s do homelab.

## Ansible

A pasta [ansible](https://github.com/guesant/hl-infrastructure/tree/main/ansible) provisiona o nó do zero: cgroups, hardening de sistema operacional (atualizações automáticas, sysctl, auditd, SSH, fail2ban), k3s sem Traefik nem ServiceLB e sem o CNI padrão, Cilium, o operador CloudNativePG, cert-manager, o plugin de backup Barman Cloud do CNPG, o próprio ArgoCD, o controlador de Sealed Secrets e o Argo CD Image Updater.

Todos os componentes acima são instalados a partir do chart Helm oficial de cada projeto (`helm template` renderizado e aplicado via `k3s kubectl apply --server-side`), no mesmo padrão; nenhum manifesto de terceiro fica vendorizado neste repositório.

Antes de rodar pela primeira vez, copie os dois arquivos de exemplo e preencha com os dados reais do host:

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
cp ansible/group_vars/all.example.yml ansible/group_vars/all.yml
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

## GitOps

A pasta [argocd](https://github.com/guesant/hl-infrastructure/tree/main/argocd) segue o padrão de app-of-apps recursivo. A subpasta root é aplicada uma única vez, pela role de bootstrap, e contém dois projetos do Argo: um para a infraestrutura definida diretamente neste repositório, com acesso amplo a recursos de cluster, e outro para satélites, restrito a recursos de namespace, com uma única exceção liberada explicitamente para o tipo StorageClass. A partir daí, uma aplicação raiz sincroniza sozinha tudo que existir na subpasta applications.

Hoje só existe um satélite ali: uma aplicação apontando para a pasta de deploy de outro repositório, com sincronização recursiva de diretório ligada. O Argo acompanha sozinho tudo que essa pasta contiver, sem exigir nenhum passo manual daqui. Um commit nesse outro repositório já basta para propagar; o Ansible deste repositório nunca precisa rodar de novo só por causa disso.

Um satélite novo entra como mais um arquivo dentro da subpasta applications, seguindo o mesmo formato do satélite existente.

## CI

Dois workflows cuidam da própria manutenção do repositório. O primeiro roda o Renovate self-hosted todo dia de manhã, isolado num environment restrito à branch principal, e sabe rebaixar o manifesto oficial inteiro de um componente vendorizado quando a versão sobe, não só trocar a tag da imagem. O segundo audita os próprios workflows com actionlint e zizmor sempre que algo muda neles. Uma receita do justfile roda os dois localmente, lendo a mesma versão pinada que o workflow usa, então nunca há duas versões divergentes para lembrar de manter sincronizadas.
