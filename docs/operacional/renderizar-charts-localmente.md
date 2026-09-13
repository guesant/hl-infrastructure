# Renderizar os charts localmente

Nenhum dos sete componentes instalados via Helm neste repositório (Cilium, ArgoCD, cert-manager, CloudNativePG, o plugin Barman Cloud, o sops-secrets-operator e Argo CD Image Updater) fica vendorizado como manifesto estático. Os dois primeiros são instalados por uma role do Ansible que roda `helm template` direto contra o repositório oficial de cada projeto; os cinco últimos são instalados pelo ArgoCD, cada um a partir de um chart local em `argocd/apps/<nome>` cuja `dependency` aponta pro chart oficial. Isso significa que, para ver os manifestos Kubernetes que qualquer um deles realmente aplica, é preciso renderizar o chart primeiro.

Rode:

```bash
just infra-render-charts
```

Essa receita constrói a imagem `helm` a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile), usando a mesma versão do Helm que `helm_version` declara em `ansible/group_vars/all/versions.yml`, e roda [.tools/render-charts.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/render-charts.sh) dentro dela. O script lê a versão dos dois charts instalados pelo Ansible do mesmo arquivo de variáveis, adiciona os dois repositórios Helm distintos que eles usam, e renderiza os cinco componentes de plataforma à parte, direto dos charts locais em `argocd/apps/<nome>`, sem precisar de repositório Helm nem de versão vinda de `versions.yml`. O resultado é um arquivo YAML por componente dentro de `rendered/`, que fica fora do git.

Depois de renderizado, é seguro inspecionar qualquer arquivo em `rendered/` com um editor comum, ou rodar `kubectl diff` contra um cluster real para ver exatamente o que mudaria antes de aplicar. Os checks de infraestrutura da CI (kube-linter, Checkov e Trivy) rodam sobre esse mesmo diretório, então reproduzir localmente o que a CI vai ver é só isso.

## Continue por aqui

Para rodar os próprios checks de lint sobre esse resultado, veja [Rodar os quality gates localmente](rodar-quality-gates-localmente.md).
