# Helm e os charts

Nenhum dos sete componentes instalados via Helm neste repositório (Cilium, cert-manager, ArgoCD, Argo CD Image Updater, CloudNativePG, o plugin Barman Cloud e Sealed Secrets) tem manifesto vendorizado. Cada role é um wrapper fino sobre o chart Helm oficial do próprio projeto: ela adiciona o repositório Helm, roda `helm template` com a versão pinada em `ansible/group_vars/all/versions.yml` e as customizações necessárias via `--set` ou um arquivo de values, e aplica o resultado com `k3s kubectl apply --server-side --force-conflicts`. O `--server-side` importa aqui porque alguns desses charts geram CRDs grandes o suficiente para estourar o limite de tamanho de anotação do apply padrão do lado do cliente.

Um manifesto de terceiro vendorizado precisaria ser buscado e substituído inteiro a cada atualização de versão, geraria diffs de milhares de linhas sem relação com a mudança real, e deixaria pouco claro quais valores foram de fato customizados em relação ao padrão do projeto original. Tratar a role como wrapper evita isso por completo.

Isso significa que uma atualização de versão é uma mudança de uma linha só no arquivo de versões, e o que muda de verdade no cluster fica visível rodando `helm template` você mesmo, sem precisar aplicar nada; veja o guia de [renderizar os charts localmente](../operacional/renderizar-charts-localmente.md).

## Versões pinadas

Cada chart tem sua versão declarada como uma variável própria em `ansible/group_vars/all/versions.yml` (`cert_manager_chart_version`, `argocd_chart_version` e assim por diante), e o Renovate rastreia cada uma dessas variáveis contra o índice Helm real do respectivo repositório, com um período de carência de sete dias antes de propor qualquer bump. Esse arquivo é o real, não um exemplo: o que o Renovate mergeia em `main` é o que o próximo `bootstrap` instala. Veja [Variáveis](variaveis.md) para a lista completa.
