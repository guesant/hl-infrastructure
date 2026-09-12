# hl-infrastructure

[![renovate](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![lint-actions](https://github.com/guesant/hl-infrastructure/actions/workflows/lint-actions.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/lint-actions.yml)
[![security](https://github.com/guesant/hl-infrastructure/actions/workflows/security.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/security.yml)
[![quality](https://github.com/guesant/hl-infrastructure/actions/workflows/quality.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/quality.yml)
[![infra-lint](https://github.com/guesant/hl-infrastructure/actions/workflows/infra-lint.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/infra-lint.yml)
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

Cinco workflows cuidam da própria manutenção do repositório e da qualidade do que ele descreve. O Renovate roda self-hosted todo dia de manhã, isolado num environment restrito à branch principal, e bumpa a versão de cada chart Helm diretamente no arquivo de variáveis, nunca um manifesto vendorizado. O lint-actions audita os próprios workflows com actionlint e zizmor sempre que algo muda neles.

Os outros três olham para o conteúdo real do repositório. O security roda Gitleaks contra todo o histórico do git, OSV-Scanner e Trivy em busca de dependências vulneráveis. O quality aplica um conjunto de regras estruturais próprias via ast-grep sobre as roles do Ansible, por exemplo exigindo que todo apply de um chart Helm use `--server-side --force-conflicts` e que toda task de comando declare `changed_when` explicitamente, além de reportar duplicação de código com jscpd sem falhar o build por isso. O infra-lint renderiza os sete charts Helm que as roles instalam e passa kube-linter, Checkov e Trivy sobre o resultado, com um conjunto restrito de checks (contêiner privilegiado, namespace de rede ou PID do host, montagem de diretório sensível do host) que efetivamente falha o build quando encontra algo; o Cilium fica de fora desses três porque uma CNI legitimamente precisa de privilégios que qualquer outro componente não deveria ter.

Cada uma dessas sete ferramentas (Gitleaks, OSV-Scanner, Trivy, kube-linter, Checkov, Helm, ast-grep e jscpd) vem de um alvo de build em [.docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.docker/Dockerfile), então a versão de cada uma fica pinada num único lugar. O workflow e a receita correspondente do justfile constroem esse mesmo alvo e rodam a imagem resultante, nunca uma imagem de terceiro puxada direto; localmente isso quer dizer `just infra-kube-linter`, `just security-gitleaks` e assim por diante, sempre um `docker run` isolado por chamada, nunca um container de longa duração.
