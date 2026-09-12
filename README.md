# hl-infrastructure

[![renovate](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![ci](https://github.com/guesant/hl-infrastructure/actions/workflows/ci.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/ci.yml)
[![docs](https://github.com/guesant/hl-infrastructure/actions/workflows/docs.yml/badge.svg)](https://github.com/guesant/hl-infrastructure/actions/workflows/docs.yml)
[![renovate dependency dashboard](https://img.shields.io/badge/renovate-dependency%20dashboard-1a1f6c.svg)](https://github.com/guesant/hl-infrastructure/issues/3)

Bootstrap único via Ansible e estado contínuo via GitOps para o cluster k3s do homelab. A documentação completa, com tutorial, arquitetura e guias operacionais, está publicada em [guesant.github.io/hl-infrastructure](https://guesant.github.io/hl-infrastructure/).

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

Três workflows cuidam da própria manutenção do repositório e da qualidade do que ele descreve. O Renovate roda self-hosted todo dia de manhã, isolado num environment restrito à branch principal, e bumpa a versão de cada chart Helm diretamente no arquivo de variáveis, nunca um manifesto vendorizado. O docs constrói o site em [docs](https://github.com/guesant/hl-infrastructure/tree/main/docs) com MkDocs a cada push e publica no GitHub Pages quando o push é em main; em pull requests, ele só constrói com `--strict` para pegar link quebrado ou página fora da navegação, sem publicar nada.

O ci reúne todo o resto num único workflow, um job por ferramenta, todos em paralelo, com um job final chamado gate que depende de todos os outros e falha se qualquer um falhar; é esse gate, sozinho, que faz sentido exigir como check obrigatório de branch, em vez de listar cada ferramenta uma por uma. actionlint e zizmor auditam os próprios workflows. Gitleaks roda contra todo o histórico do git, OSV-Scanner e Trivy procuram dependências vulneráveis. ast-grep aplica um conjunto de regras estruturais próprias sobre todo o repositório, por exemplo exigindo que todo apply de um chart Helm use `--server-side --force-conflicts`, que toda task de comando declare `changed_when` explicitamente, e que nenhum arquivo YAML ou shell carregue um comentário narrativo; só passam diretivas exigidas por uma ferramenta (`shellcheck`, `yamllint`, `zizmor: ignore[...]` e afins) e o marcador `IMPORTANT:` para um invariante crítico e não óbvio. jscpd reporta duplicação de código sem falhar o build por isso. kube-linter, Checkov e Trivy renderizam os sete charts Helm que as roles instalam e checam o resultado, com um conjunto restrito de checks (contêiner privilegiado, namespace de rede ou PID do host, montagem de diretório sensível do host) que efetivamente falha o build quando encontra algo; o Cilium fica de fora desses três porque uma CNI legitimamente precisa de privilégios que qualquer outro componente não deveria ter.

Cada uma dessas sete ferramentas (Gitleaks, OSV-Scanner, Trivy, kube-linter, Checkov, Helm, ast-grep e jscpd) vem de um alvo de build em [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile), então a versão de cada uma fica pinada num único lugar. O workflow e a receita correspondente do justfile constroem esse mesmo alvo e rodam a imagem resultante, nunca uma imagem de terceiro puxada direto; localmente isso quer dizer `just infra-kube-linter`, `just security-gitleaks` e assim por diante, sempre um `docker run` isolado por chamada, nunca um container de longa duração.
