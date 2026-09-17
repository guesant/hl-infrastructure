# Renderizar os charts localmente

<!-- source-of-trust paths=".tools/render-charts.sh" -->

Nenhum dos componentes instalados via Helm neste repositório (Cilium, ArgoCD, cert-manager, CloudNativePG, o sops-secrets-operator, o Kargo e os demais wrappers de `argocd/apps`) fica vendorizado como manifesto estático. Cilium e ArgoCD são instalados por uma role do Ansible que roda `helm template` direto contra o repositório oficial de cada projeto; os demais são instalados pelo ArgoCD, cada um a partir de um chart local em `argocd/apps/operators/<nome>` ou `argocd/apps/platform/<nome>` cuja `dependency` aponta pro chart oficial. Isso significa que, para ver os manifestos Kubernetes que qualquer um deles realmente aplica, é preciso renderizar o chart primeiro.

Rode:

```bash
just infra-render-charts
```

Essa receita constrói a imagem `helm` a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile), usando a mesma versão do Helm que `helm_version` declara em `ansible/group_vars/all/versions.yml`, e roda [.tools/render-charts.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/render-charts.sh) dentro dela. O script lê a versão dos charts instalados pelo Ansible do mesmo arquivo de variáveis, adiciona os repositórios Helm distintos que eles usam e confere o `.tgz` de cada um contra o digest declarado em `versions.yml` antes de renderizar, o mesmo par que a role `cilium` e a role `argocd` conferem no node. Praticamente todo o resto vem direto da fonte local, sem depender de repositório Helm nem de versão vinda de `versions.yml`: os wrappers de `argocd/apps/operators/` e `argocd/apps/platform/`, mais os charts de satélite (`argocd/apps/satellites/launcher`, que emite a `Application` de cada satélite a partir de uma lista, `argocd/apps/satellites/delivery`, que faz o mesmo para a entrega do Kargo, e a entrega antiga do blog em `argocd/apps/satellites/blog/delivery`, mantida até a migração para o chart de lista terminar). O conjunto exato do que é renderizado muda com o tempo, à medida que componentes novos entram no cluster; [.tools/render-charts.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/render-charts.sh) é a fonte da verdade de quais. O resultado é um arquivo YAML por componente dentro de `.build/rendered/`, que fica fora do git.

Depois de renderizado, é seguro inspecionar qualquer arquivo em `.build/rendered/` com um editor comum, ou rodar `kubectl diff` contra um cluster real para ver exatamente o que mudaria antes de aplicar. Os checks de infraestrutura da CI (kube-linter, Checkov e Trivy) rodam sobre esse mesmo diretório, então reproduzir localmente o que a CI vai ver é só isso.

## Continue por aqui

Para rodar os próprios checks de lint sobre esse resultado, veja [Rodar os quality gates localmente](rodar-quality-gates-localmente.md).
