# hl-infrastructure

Bootstrap único via Ansible e estado contínuo via GitOps (ArgoCD) para o cluster k3s homelab. Migrado de `guesant/blog`'s `deploy/ansible/` em 2026-09-12; o histórico de decisões anterior a essa data está em `docs/pendencias-e-decisoes.md` do repositório `blog`.

## Ansible (`ansible/`)

Provisiona o nó do zero: cgroups, hardening de SO (unattended-upgrades, sysctl, auditd, SSH, fail2ban), k3s (sem Traefik/ServiceLB, sem o CNI padrão), Cilium, o operador CloudNativePG, cert-manager, o plugin CNPG-I Barman Cloud, ArgoCD, o controlador de Sealed Secrets e o Argo CD Image Updater.

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
cp ansible/group_vars/all.example.yml ansible/group_vars/all.yml
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

## GitOps (`argocd/`)

App-of-apps recursivo. `argocd/root/` (aplicado uma única vez pela role `bootstrap-app`) contém dois `AppProject` (`infra`, cluster-wide, só para recursos definidos neste próprio repositório; `satellites`, restrito a recursos namespaced, com uma única exceção documentada para `StorageClass`) e a `Application` "root", que sincroniza `argocd/applications/` deste mesmo repositório.

`argocd/applications/blog-satellite.yaml` é uma `Application` (projeto `satellites`) apontando para `deploy/gitops/applications/` do repositório `guesant/blog`, com `directory.recurse: true`. A partir daí, o Argo sincroniza sozinho tudo que esse diretório contém (hoje: as Applications `blog`, `postgres`, `cloudflared`, `network-policies` e o `ImageUpdater`), sem nenhum passo manual adicional: um commit em `deploy/gitops/applications/` no repositório `blog` já é suficiente, o Ansible deste repositório nunca precisa rodar de novo só por causa disso.

Novos satélites (outro repositório de aplicação) entram como um novo arquivo em `argocd/applications/`, seguindo o mesmo padrão do `blog-satellite.yaml`.
