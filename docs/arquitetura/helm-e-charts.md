# Helm e os charts

Nenhum dos componentes instalados via Helm pelo Ansible (Cilium e ArgoCD) tem manifesto vendorizado. Cada role é um wrapper fino sobre o chart Helm oficial do próprio projeto: ela adiciona o repositório Helm, roda `helm template` com a versão pinada no arquivo de versões e as customizações necessárias via flags ou um arquivo de values, e aplica o resultado com `k3s kubectl apply --server-side --force-conflicts`.

O server-side apply importa aqui porque alguns desses charts geram CRDs grandes o suficiente para estourar o limite de tamanho de anotação do apply padrão do lado do cliente.

O cert-manager e o operador CloudNativePG seguem um wrapper parecido, mas fora do Ansible: um chart local em `argocd/apps/operators/<nome>` para cada um ([cert-manager](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps/operators/cert-manager), [cnpg](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps/operators/cnpg)). Os operadores de secrets ficam agrupados em `argocd/apps/secrets/operators/`, com o chart upstream como dependência do Chart.yaml e um arquivo de values commitado quando há customização, sincronizados como aplicações do ArgoCD em vez de aplicados pelo Ansible.

O Kargo segue o mesmo wrapper, mas em `argocd/apps/platform/kargo`, e não em `operators/`, porque não gerencia CRD nem recurso de outro componente: é uma ferramenta de plataforma que edita a própria aplicação do Argo.

A separação entre os dois diretórios não é cosmética: `operators/` reúne o que instala CRD e reconcilia recurso de outro componente, e é esse critério, não a ordem de instalação, que decide onde um chart novo entra.

Esses componentes ficarem fora do Ansible não abre exceção ao padrão; a regra é a mesma, com outro executor. Continua não havendo manifesto vendorizado, e quem aplica o resultado é o Argo, no lugar do `kubectl` de uma role. A exceção de verdade são o Cilium e o ArgoCD, que ficam permanentemente fora do GitOps por serem pré-requisitos de bootstrap: precisam existir antes de qualquer `Application` poder sincronizar.

"Nenhum manifesto vendorizado" não significa nenhum arquivo vendorizado: cada um desses charts locais carrega um `Chart.lock` e um `.tgz` do chart upstream dentro do próprio diretório do chart, gerados pelo gerenciador de dependências do Helm e commitados junto com o resto do chart.

O que não é vendorizado é o manifesto Kubernetes já renderizado; o chart em si, do jeito que o autor upstream o distribui, precisa estar disponível sem depender de rede no momento do sync, porque o Argo roda `helm template` a partir do conteúdo do repositório, não busca o repositório Helm remoto a cada ciclo.

O preço disso aparece no diff: subir a versão da dependência exige regerar o pacote e commitá-lo, então um bump de operador carrega um arquivo binário junto. Em troca, o sync não depende de o repositório Helm upstream estar no ar, e a versão que o cluster recebe é exatamente a que foi revisada no pull request.

Um manifesto de terceiro vendorizado precisaria ser buscado e substituído inteiro a cada atualização de versão, geraria diffs de milhares de linhas sem relação com a mudança real, e deixaria pouco claro quais valores foram de fato customizados em relação ao padrão do projeto original.

Tratar a role como wrapper evita isso por completo: uma atualização de versão vira uma mudança de uma linha só no arquivo de versões, e o que muda de verdade no cluster fica visível rodando `helm template` você mesmo, sem precisar aplicar nada. Veja o guia de [renderizar os charts localmente](../operacional/renderizar-charts-localmente.md).

Renderizar em vez de instalar tem uma consequência menos óbvia. Como nenhuma dessas roles usa `helm upgrade`, não existe release de Helm guardando estado.

A função `lookup`, que um chart usa para enxergar um objeto já existente no cluster e reaproveitá-lo, sempre volta vazia dentro de `helm template`, mesmo com um kubeconfig válido disponível.

Um chart que usa `lookup` para preservar um segredo gerado na primeira instalação não tem como saber que ele já existe, e o template escreve um valor novo como se fosse a primeira vez. O comportamento não é um bug do Helm: renderizar é offline por definição, e é justamente por isso que ele serve para revisar o manifesto antes de aplicar.

O chart do Cilium depende exatamente dessa função para não gerar uma CA nova a cada instalação, no modo `hubble.tls.auto.method: helm` que é o padrão dele. Sob este padrão de renderização, portanto, toda reaplicação regenerava a CA do Cilium e os certificados do Hubble do zero.

O sintoma apareceu ao ligar `policyAuditMode: false`: o diff por server-side mostrava três segredos sendo trocados, sem nenhuma mudança de values relacionada a eles.

| Segredo trocado | O quê |
| --- | --- |
| `cilium-ca` | CA do Cilium |
| `hubble-relay-client-certs` | certificado de cliente do relay |
| `hubble-server-certs` | certificado de servidor do Hubble |

A correção é `hubble.tls.auto.method: cronJob`. Nesse modo os certificados são emitidos por um Job que roda `cilium-certgen --ca-reuse-secret` dentro do cluster, então quem decide se a CA existente é reaproveitada é o próprio servidor, e não uma função avaliada em tempo de render, do mesmo jeito que o diff por server-side já decide o resto.

O efeito prático é que uma reaplicação do Cilium deixou de aparecer no diff trocando a CA e os certificados do Hubble sem que nenhum value ligado a eles tivesse mudado. O padrão que fica é mais geral do que o caso do Cilium: sob renderização, qualquer decisão que dependa do estado atual do cluster precisa acontecer no servidor, não no template.

## Charts sem dependência: gerar várias instâncias em vez de embrulhar um upstream

Nem todo chart local em `argocd/apps` embrulha um chart de terceiro. O launcher e a delivery de satélites não têm dependências declaradas no Chart.yaml: são um chart Helm só de templates próprios, cujo arquivo de values guarda uma lista, e cujos templates emitem um objeto do Kubernetes por item da lista, uma aplicação do Argo no caso do launcher e os objetos de entrega do Kargo no caso da delivery.

O padrão está descrito por extenso em [GitOps: root e satélites](gitops-root-e-satelites.md) e o mecanismo geral de gerar várias instâncias assim, incluindo o cuidado necessário para não colidir com a sintaxe de expressão do próprio Kargo, está em [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md). O ganho é concentrar num item de lista tudo que distingue um satélite do outro, em vez de duplicar um manifesto inteiro por repositório novo.

Os dois preenchem essa lista de formas diferentes: a delivery a traz commitada no próprio arquivo de values, enquanto o launcher entra com a lista vazia e recebe a lista real pelos values inline da aplicação wrapper que o sincroniza.

O Keycloak (`argocd/apps/platform/keycloak`), o Portainer e o kube-bench são outra variante ainda, sem chart upstream nenhum: manifestos próprios e curtos, escritos porque o projeto não publica chart Helm ou porque o chart oficial não expõe o [securityContext](../aprender/jobs-cronjobs-e-securitycontext.md) que as políticas de admissão exigem.

São charts pequenos o bastante para caber em poucos templates: o Keycloak tem um StatefulSet, um Service e um ServiceAccount; o kube-bench, um CronJob e o RBAC dele. Escrever o manifesto à mão aqui custa menos do que embrulhar um chart upstream e depois lutar contra os valores que ele não deixa sobrescrever, e o contexto de segurança fica explícito no arquivo em vez de depender de um value do autor original.

## Versões pinadas

Cada chart instalado pelo Ansible tem sua versão declarada como uma variável própria no arquivo de versões, acompanhada do SHA-256 do pacote, listadas na tabela abaixo para o ArgoCD e o Cilium: a role puxa o chart para `/etc/rancher/charts`, confere o digest e renderiza a partir do arquivo, nunca direto do índice do repositório, e o script de renderização faz a mesma conferência na CI.

| Componente | Variável de versão | Variável de digest |
| --- | --- | --- |
| ArgoCD | `argocd_chart_version` | `argocd_chart_sha256` |
| Cilium | `cilium_version` | `cilium_chart_sha256` |

Esse arquivo é o real, não um exemplo: o que o Renovate mergeia no branch principal é o que o próximo bootstrap instala. Quando o pacote baixado não bate com o digest declarado, o script de renderização aborta e diz para revisar o chart e atualizar o digest, em vez de renderizar o que veio.

Isso transforma uma versão republicada com conteúdo diferente, que passaria despercebida se a pinagem fosse só pelo número, numa falha de CI.

O Renovate rastreia cada uma dessas variáveis contra o índice Helm real do respectivo repositório, com o período de carência declarado em `.github/renovate.json` antes de propor qualquer bump. A versão dos componentes locais (operators e platform) sincronizados pelo Argo foge a essa regra de propósito: ela vive na dependência do Chart.yaml local de cada um, e o Renovate a atualiza pelo gerenciador nativo de chart Helm, sem regex customizado.

Veja [Variáveis](variaveis.md) para a lista completa.

## Continue por aqui

[A pipeline de CI](ci.md) mostra onde o digest de cada chart é conferido antes de renderizar; [variáveis](variaveis.md) lista cada versão declarada.
