# Renderizar os charts localmente

Nenhum dos sete componentes instalados via Helm neste repositório (Cilium, cert-manager, ArgoCD, Argo CD Image Updater, CloudNativePG, o plugin Barman Cloud e Sealed Secrets) fica vendorizado como manifesto estático; as roles do Ansible rodam `helm template` direto contra o repositório oficial de cada projeto. Isso significa que, para ver os manifestos Kubernetes que uma role realmente vai aplicar, é preciso renderizar o chart primeiro.

Rode:

```bash
just infra-render-charts
```

Essa receita constrói a imagem `helm` a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile), usando a mesma versão do Helm que `helm_version` declara em `ansible/group_vars/all/versions.yml`, e roda [.tools/render-charts.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/render-charts.sh) dentro dela. O script lê a versão de cada chart do mesmo arquivo de variáveis, adiciona os cinco repositórios Helm distintos e escreve um arquivo YAML por componente dentro de `rendered/`, que fica fora do git.

Depois de renderizado, é seguro inspecionar qualquer arquivo em `rendered/` com um editor comum, ou rodar `kubectl diff` contra um cluster real para ver exatamente o que mudaria antes de aplicar. Os checks de infraestrutura da CI (kube-linter, Checkov e Trivy) rodam sobre esse mesmo diretório, então reproduzir localmente o que a CI vai ver é só isso.

## Continue por aqui

Para rodar os próprios checks de lint sobre esse resultado, veja [Rodar os quality gates localmente](rodar-quality-gates-localmente.md).
