# GitOps: root e satélites

<!-- source-of-trust paths="argocd" -->

O ArgoCD sincroniza este cluster a partir de um padrão de app-of-apps recursivo, com os projetos `infra/satellites`, que têm permissões bem diferentes, ambos declarados como `AppProject`.

Os charts locais seguem a mesma separação: `values.yaml` concentra nomes, imagens, portas, recursos e demais parâmetros operacionais, enquanto os templates preservam apenas a composição dos recursos, condicionais e iterações. Isso mantém a mudança de configuração separada da estrutura Kubernetes que a aplica.

App-of-apps recursivo quer dizer que uma aplicação do Argo não descreve um workload, e sim um diretório de outras aplicações, que por sua vez podem descrever mais um.

Uma única aplicação aplicada à mão no bootstrap basta para o resto do cluster aparecer sozinho. O projeto ao qual cada aplicação pertence é o que limita o que ela pode criar, e é nessa diferença de teto que se apoia a maior parte das decisões desta página.

O projeto `infra` cobre a infraestrutura definida diretamente neste repositório e tem acesso amplo em escopo de cluster, listado na tabela abaixo, incluindo os tipos que um operator de plataforma precisa para se instalar.

| Recurso de cluster liberado ao projeto `infra` |
| --- |
| `Namespace` |
| `AppProject` |
| `Application` |
| `CustomResourceDefinition` |
| `ClusterRole` |
| `ClusterRoleBinding` |
| Configurações de webhook de admissão |
| `StorageClass` (a que o app `storage` cria para o provisioner) |

É nele que vive a aplicação `root`, aplicada uma única vez pela role `bootstrap_app`, com fontes múltiplas: a pasta [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications), com sincronização recursiva de diretório ligada.

A outra fonte são os `project-*.yaml` de [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root).

Qualquer arquivo `Application` novo colocado ali é detectado e sincronizado pelo Argo sozinho, sem nenhum passo manual.

O mesmo vale para uma mudança num `AppProject`, como liberar um tipo novo no `clusterResourceWhitelist`.

Os projetos entrarem como fonte do `root` foi uma correção.

Antes, eles só mudavam num `just bootstrap`, e isso fez algumas `Application` falharem a sincronização no mesmo dia: o Argo tentava aplicar um tipo que o projeto ainda não liberava, esgotava as tentativas e parava.

Os projetos em `argocd/root` levam `Prune=false,Delete=false`, porque a aplicação root roda dentro do projeto de infraestrutura e não pode apagar o projeto do qual depende.

O `application.yaml` do próprio root continua fora dessa fonte e só muda pelo `bootstrap_app`.

Isso existe para que um erro nele não consiga desfazer o próprio root.

O projeto `satellites` é deliberadamente restrito: só pode criar recursos de escopo de namespace, com três exceções liberadas explicitamente no `clusterResourceWhitelist`.

Essas exceções são `Namespace/StorageClass` e o `Project` do Kargo.

Uma `Application` sob esse projeto não consegue criar um recurso de cluster como `ClusterRole/CustomResourceDefinition`, mesmo que o operador do Argo quisesse.

A permissão simplesmente não existe no projeto.

Isso significa que qualquer coisa declarada sob `satellites` nunca pode, por engano, escalar para um recurso de cluster inteiro.

O que define esse teto de permissão é o projeto declarado no `spec.project` da aplicação, não o repositório que a declara: uma aplicação sob `satellites` fica igualmente restrita apontando para este repositório ou para um repositório de terceiro.

Existe ainda o projeto `default`, que o próprio ArgoCD cria na instalação com permissão total; [argocd/root/project-default.yaml](https://github.com/guesant/hl-infrastructure/blob/main/argocd/root/project-default.yaml) o sobrescreve com listas vazias de repositórios, destinos e recursos permitidos.

Sem isso, a restrição do projeto `satellites` seria contornável um nível abaixo: uma `Application` sob esse teto não pode criar recurso de cluster.

Mas uma aplicação filha declarando `project: default` poderia.

Com o `default` fechado, um filho que esqueça de declarar `project: satellites` simplesmente não sincroniza, e o erro aparece no próprio Argo.

Originalmente, cada satélite era ele mesmo outra `Application` de sincronização recursiva de diretório, apontando para uma pasta de GitOps dentro do repositório da própria aplicação; um satélite novo, de terceiros, ainda segue esse formato, descrito no guia [adicionar um satélite novo](../operacional/adicionar-um-satelite.md).

O único satélite que existe hoje, o blog, não segue mais esse formato. A mudança não aposentou o padrão: ela reconheceu que, com um operador só cuidando dos dois repositórios, o custo da separação não estava comprando nada. A seção seguinte explica esse caso e deixa claro o que continuaria valendo se um segundo repositório, com outro dono, entrasse na jogada.

## Por que o blog não é um satélite de verdade

O blog, servido em `guesant.net`, só parece um satélite comum à primeira vista.

As peças que ele precisa no cluster, o app em si, o túnel Cloudflare, as políticas de rede do namespace e o projeto de entrega do Kargo, vivem direto em `argocd/applications/satellites/blog/` e `argocd/apps/satellites/blog/`.

Elas vivem dentro deste repositório, sob o projeto `satellites`, com o mesmo teto de permissão de qualquer satélite. O repositório `guesant/blog` não declara nenhum objeto do Argo.

A razão não é técnica, é organizacional: como o mesmo operador administra ambos os repositórios, separar "o que é infraestrutura" de "o que é aplicação" em repositórios diferentes não reduz risco algum, só multiplica onde uma mudança de deploy precisa ser feita.

O padrão de satélite continua existindo e documentado para o cenário em que ele resolve um problema real, um futuro colaborador ou uma automação com acesso de escrita só ao repositório da aplicação, não a este.

O banco é mantido pela aplicação `shared-postgres`, em `argocd/applications/data/shared-postgres.yaml` e `argocd/apps/data/shared-postgres/`. Ela cria um único `Cluster` do CloudNativePG no namespace `data`, com bancos e roles separados para o portfólio e o Keycloak.

Essa separação mantém o dado fora das aplicações que o consomem sem criar um cluster por aplicação. Os objetos `Database` e `DatabaseRole` têm política de retenção, enquanto cada consumidor recebe seu próprio Secret por `ExternalSecret` no namespace correspondente.

As imagens do blog ficam registradas no chart por digest, incluindo o public-app e o Laravel. O Kargo resolve a imagem publicada pela branch `main` e o Argo aplica a revisão promovida, sem depender de uma tag mutável durante a execução.

O critério que separa a pasta do satélite da camada de dado é a política de remoção, não a titularidade: um banco exclusivo de uma aplicação continua sendo dado, e dado sai do cluster por um caminho mais conservador do que o resto.

Manter as duas coisas na mesma pasta convidaria a aplicar a elas a mesma política de prune, que é exatamente o erro que a separação evita.

O app e o cloudflared rodam cada um com uma `ServiceAccount` própria, criada pelo chart, sem token da API montado, porque nenhum dos processos fala com o Kubernetes, e com o sistema de arquivos raiz somente leitura.

O app escreve só nos volumes declarados: um `emptyDir` para `/tmp` e para os assets públicos.

O outro volume é um PVC em `/data/resume-cache`, onde o tectonic guarda o bundle LaTeX pesado que baixa uma vez para gerar o PDF do currículo.

Num `emptyDir` esse cache morria a cada réplica nova e, com `TECTONIC_ONLY_CACHED` ligado pela imagem, a geração falhava sempre por não achar o formato.

O `ConfigMap` do chart desliga essa trava e o volume persiste o download.

O sops-secrets-operator segue o mesmo padrão de endurecimento, com o `securityContext` do chart ligado: seccomp `RuntimeDefault`, sem root, sem escalada e sem capabilities.

Ele é a única peça desta lista que precisa de um token de `ServiceAccount`, porque o trabalho dele é justamente escrever segredos no cluster a partir do que está cifrado no git. Endurecer o resto do pod importa mais nesse caso, e não menos, já que um processo com esse acesso é o alvo mais atraente do namespace.

O schema do banco do blog nunca é tocado pelo processo web.

O chart declara um Job `PreSync` (`job.jobs.migrate` nos values).

Ele roda na mesma imagem e com o mesmo `Secret` do CNPG.

Esse Job roda o bundle de migrações do EF Core que a imagem traz em `/app/migrate`, e o Argo só troca o `Deployment` depois que ele termina, como descrito em [Rollout de imagens](rollout-de-imagens.md).

Durante a transição, o Job aceita tanto o bundle EF legado em `/app/migrate` quanto `php artisan migrate --force` da imagem Laravel, dependendo de qual imagem está de fato entrando.

As sondas de vida e prontidão do app Laravel, no endpoint `/up`, também levam um atraso inicial maior do que a imagem anterior usava, porque o boot no Raspberry Pi demora mais do que os poucos segundos que bastavam antes; o mesmo padrão já vale para a sonda de startup do Grafana, descrita adiante.

Um detalhe do chart `application` que já custou um sync: no template de `Job` ele escreve o comando como texto simples, não como lista YAML.

Isso faz um comando com argumentos virar um único executável inexistente.

Por isso o Job declara `command: [/bin/sh]` e o script em `args`, que o chart serializa corretamente. Como um hook não conta como deriva, uma mudança só no Job não dispara o sync automático; ela entra no próximo sync real, ou num sync pedido à mão.

Todo namespace criado por uma aplicação recebe os labels de Pod Security `restricted` nos três modos (`enforce/warn/audit`).

Nos operadores, isso vem do `managedNamespaceMetadata` do `syncPolicy` da própria aplicação.

O `Namespace/blog`, com os mesmos labels, é declarado à parte em `argocd/apps/platform/namespaces`.

Essa aplicação, do projeto de infraestrutura, leva `prune` desligado e `Delete=false`, para que nenhuma remoção em cascata vinda do satélite apague o namespace com tudo dentro.

O `kube-system` fica de fora, porque o Cilium e os componentes do k3s precisam de privilégio.

O job `pod-security` da CI falha se um namespace novo nascer sem o label de `enforce`.

Cada peça que precisa de segredo declara o próprio `SopsSecret` no chart wrapper local.

Nenhuma delas usa mais `SealedSecret`, o mecanismo antigo, removido junto com o controller que o cifrava.

| Arquivo do `SopsSecret` | O que guarda | Como chega ao processo |
| --- | --- | --- |
| `blog/templates/admin-oidc.sops-secret.yaml` | Client secret do login do admin pelo realm `homelab` do Keycloak | Arquivo montado em `/secrets/app`, lido com `AddKeyPerFile` |
| `cloudflared/templates/tunnel-token.sops-secret.yaml` | Token do túnel Cloudflare | Variável de ambiente do processo cloudflared |

O `admin-oidc.sops-secret.yaml` entrega o segredo como arquivo, e não como variável de ambiente, que vazaria para qualquer processo filho e para dumps do processo; o `fsGroup` do pod deixa os arquivos legíveis só para o usuário do app. As regras de ingress do túnel não moram mais no chart, e sim na própria Cloudflare, declaradas em [OpenTofu: a camada da Cloudflare](opentofu.md).

### Políticas de rede

O Cilium roda com `policyEnforcementMode: always`, em que todo pod nega por padrão qualquer tráfego que nenhuma política libere, com ou sem política própria.

Por isso cada namespace tem uma `CiliumNetworkPolicy` que lista o que ele de fato usa, levantado nos veredictos `AUDIT` do Hubble.

`argocd/apps/platform/network-policies`, no projeto de infraestrutura, cobre os namespaces `argocd/cert-manager/cnpg-system/sops/kube-system`.

Ela libera DNS para o CoreDNS, API server, entrada vinda do host e do API server para sondas, métricas e webhooks, saída 443 do Argo CD para o GitHub e os registros, e o CNPG falando com o banco compartilhado.

O chart de políticas do blog ganha as de saída do próprio namespace: DNS, o app para o Postgres e para a internet em 443, o cloudflared para o app, para o `argocd-server`, para o Keycloak e para a borda da Cloudflare, o Postgres para o API server.

O cloudflared alcança o Keycloak porque `auth.guesant.net` entra pelo mesmo túnel do blog e é roteado direto para o servidor, sem passar pelo app.

A regra correspondente já existia, mas com um seletor de rótulo que não batia com o pod real (`app: keycloak` em vez de `app.kubernetes.io/name: keycloak`), então essa saída ficava bloqueada até o rótulo ser corrigido.

Desde que `policyAuditMode` virou `false` (ver [checklist de segurança](checklist-de-seguranca.md)), essas regras bloqueiam de verdade o que não liberam, não só registram.

O namespace `blog` é o único do cluster com mais de um mecanismo de política de rede ao mesmo tempo, e não por uma migração pela metade.

O ingress vem de `NetworkPolicy` nativa do Kubernetes, com a regra `default-deny-ingress` mais três regras específicas.

Essas regras são `allow-app-to-postgres/allow-cloudflared-to-app/allow-cnpg-operator-to-postgres`, enquanto o egress e a linha de base ficam com `CiliumNetworkPolicy/CiliumClusterwideNetworkPolicy`.

Ambos convivem de propósito, e depurar conectividade nesse namespace exige olhar ambos os tipos de recurso, `kubectl get networkpolicy` e `kubectl get ciliumnetworkpolicy`, porque cada um só enxerga a metade do tráfego que declara.

O endpoint de health do próprio Cilium também cai na regra do `always`: o ping que o agente faz nele a partir do host seria descartado e o `cilium-health` passaria a reportar o node como inalcançável, sem que nenhum pod perdesse tráfego.

Como esse endpoint não pertence a namespace nenhum, a liberação é uma `CiliumClusterwideNetworkPolicy` (`templates/cilium-health.yaml`).

Ela cobre ICMP echo e TCP 4240 vindos de `host/remote-node`.

O projeto de infraestrutura libera esse tipo de recurso no `clusterResourceWhitelist`.

O caso ilustra bem o preço de negar por padrão: o que quebra primeiro não é o tráfego da aplicação, que alguém pensou em liberar, e sim a checagem interna que ninguém lembrou de declarar. Liberar `remote-node` junto de `host`, mesmo num node só, evita que a mesma regra precise ser revisitada quando um segundo node entrar.

## Como a pasta de applications é organizada

Dentro de `argocd/applications`, cada subpasta corresponde a uma camada, e a camada define a onda de sincronização (`argocd.argoproj.io/sync-wave`) que todo arquivo dentro dela carrega.

O Argo aplica as ondas em ordem crescente e só avança para a próxima quando todos os recursos da onda anterior estão saudáveis, então a camada é o que garante que um satélite nunca sincronize antes de uma dependência de plataforma que ele precise. A distância entre as ondas é deliberada: sobra espaço para inserir uma camada intermediária no futuro sem renumerar o que já existe.

| Pasta | Onda | O que vive ali |
| --- | --- | --- |
| `operators/` | `0` | Controllers que gerenciam CRD ou recurso de outro componente: cert-manager (certificados), CNPG (`Cluster` do Postgres) e o sops-secrets-operator (`SopsSecret`); todos no projeto `infra` |
| `platform/` | `0` | Ferramentas de plataforma de uso direto, que não existem para gerenciar CRD de outra coisa: o Kargo, que promove imagens dos satélites editando a própria `Application` do Argo (veja [Rollout de imagens](rollout-de-imagens.md)), os namespaces, as políticas de rede, o kube-bench, as políticas de admissão, o [ingress](ingress.md) (Traefik com Gateway API, as `HTTPRoute` dos nomes internos e a CA interna), o Portainer, o Dashy, o Reloader, os segredos de OIDC (`sso`) e o `oauth2-proxy`; também no projeto `infra` |
| `data/` | `1` | Dados com estado, dedicados ou compartilhados, mantidos fora das aplicações que os consomem; hoje `shared-postgres`, um `Cluster` do CNPG com bancos separados para o portfólio e o Keycloak, no projeto `infra` |
| `satellites/<nome>/` | `0` a `3` | As `Application` de um satélite consolidado neste repositório, no projeto `satellites`; hoje só `satellites/blog/`, com onda própria por peça (rede na onda `0`, antes do app na `2`, antes do túnel na `3`) |
| `satellites/launcher/` e `satellites/delivery/` | `0` e `1` | Exceção à regra de uma pasta por satélite: charts com array de instâncias em `values.yaml`, descritos na seção seguinte |

Todas essas pastas vêm de um mini chart wrapper em [argocd/apps](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps), organizado nas mesmas categorias, não de um chart upstream apontado direto, para manter `sourceRepos` do projeto `infra` restrito a este único repositório.

Os values desses wrappers declaram `requests` e limite de memória de cada operador, medidos contra o consumo real, e pinam as imagens por digest.

O cert-manager usa o campo `image.digest` do próprio chart, e CNPG, sops-secrets-operator e Kargo usam o formato `tag@sha256:...`, que o Renovate atualiza junto da tag.

Apontar direto para um chart upstream funcionaria, mas obrigaria a incluir o repositório dele em `sourceRepos`, e a partir daí qualquer aplicação do projeto `infra` poderia sincronizar de lá. Manter a lista com um endereço só transforma "de onde este cluster aceita manifesto" numa resposta de uma linha, verificável sem ler cada aplicação.

O app do blog separa o frontend do Laravel. O frontend mantém uma réplica com request de `200m` e limite de `1000m` de CPU, enquanto o Laravel mantém duas réplicas com request de `50m` e limite de `1000m` por pod. O worker tem limite de `400m` e o scheduler tem limite de `200m`. A quota do namespace reserva `4200m` de limite de CPU para acomodar a carga observada sem alterar a memória.

O Laravel também executa dois workers do servidor PHP em cada pod, e o worker de filas permanece habilitado para a fila `default`. O scheduler continua desligado nesta configuração. A imagem Laravel é fixada por digest no values do chart, e a promoção do Kargo é a autoridade para trocar esse digest.

Não ficou sem limite porque o namespace `blog` carrega um `LimitRange` que injeta um limite default em todo container sem um declarado.

Esse `LimitRange` se chama `blog-namespace-limits`, no chart de políticas de rede.

Um `request` maior que esse default torna o pod inválido na criação, como aconteceu na primeira tentativa desta mudança.

A sequência explica por que o limite existe mesmo sem concorrência por CPU: ele não está lá para proteger vizinhos, e sim porque o namespace exige que todo contêiner tenha um. Declarar o valor certo é melhor do que herdar o default, que foi escolhido para um workload qualquer e não para um que renderiza página sob demanda.

Os `Deployment` do frontend e do Laravel rodam com `strategy.type: Recreate`. O Laravel usa duas réplicas para atender a leitura pública e mantém o PVC compartilhado do cache do currículo, que exige `ReadWriteOnce`; a estratégia evita uma sobreposição de pods durante uma atualização.

O `PVC` de `/data/resume-cache` não suporta dois pods montando o mesmo volume ao mesmo tempo.

O chart wrapper precisa declarar `rollingUpdate: null` junto desse tipo, pelo mesmo motivo descrito adiante para o Grafana.

O server-side apply do Argo recusa trocar o tipo da estratégia enquanto o `Deployment` vivo ainda carrega o bloco `rollingUpdate` de uma renderização anterior.

O `readinessProbe` do app aponta para `/health/ready`, não para o endpoint que continua servindo só a sonda de vida.

A diferença importa num rolling update: `/health` responde assim que o processo sobe, mesmo antes do pool de conexão com o Postgres existir, e o Service já mandaria tráfego real para um pod cuja primeira leitura de conteúdo falha.

`/health/ready` roda um `select 1` contra o banco, com um teto de tempo próprio.

Ele só devolve `200` depois que essa conexão responde de verdade.

O `timeoutSeconds: 3` da sonda existe para não competir com esse teto interno: sem essa folga, o próprio Kubernetes derrubaria a sonda por timeout antes do `select 1` ter chance de responder.

A divisão entre `operators/platform` existe porque cada um falha de forma diferente: um operator que sai do ar deixa objetos que ele já criou (um `Certificate/Cluster`) sem reconciliação, enquanto uma ferramenta de plataforma que sai do ar só perde a própria função.

`data/` fica fora da pasta do satélite mesmo quando o dado é exclusivo dele, porque o teto de permissão de dado, com retenção de PVC e `Prune=false` no recurso, é sempre mais conservador que o do resto do satélite.

Misturá-los nivela o mais restritivo pelo menos restritivo por engano.

As três pastas respondem, no fim, a uma pergunta só: o que sobra se esta peça sumir do git amanhã. Some um operator e ficam objetos sem quem os reconcilie; some uma ferramenta de plataforma e some só ela; some um banco e some o dado, que é o único caso irreversível.

## Satélites e entrega do Kargo: um chart com array, não um arquivo por instância

O padrão de satélite que `satellite-add` escreve, uma `Application` inteira para um repositório de terceiro, é a estrutura que de fato se repete a cada satélite novo, ao contrário do blog, que é a exceção descrita acima.

O de entrega do Kargo que `satellite-delivery-add` escreve segue o mesmo padrão: um projeto de entrega inteiro para cada satélite que promove imagem.

Adicionar um satélite continha o mesmo bloco de `syncPolicy` copiado por inteiro a cada arquivo novo, e adicionar uma entrega continha uma pasta de vários arquivos com nome, namespace e imagem grafados em todos eles; a estrutura em si nunca mudava de um satélite para o outro, só os valores.

Duplicação assim não incomoda enquanto há um satélite; ela cobra na primeira vez que a estrutura precisa mudar, porque a mudança tem de ser repetida em cada cópia, e uma esquecida só aparece quando aquele satélite falha. O que segue é a troca desse molde copiado por um chart que gera as instâncias a partir de uma lista.

Um par de charts resolve isso.

O chart em `argocd/apps/satellites/launcher` é sincronizado por uma `Application` wrapper.

Essa aplicação se chama `satellites-launcher`.

Esse chart tem um `values.yaml` com uma lista `satellites`.

O `templates/application.yaml` usa `{{- range .Values.satellites }}` para emitir uma aplicação por item.

Ele é automático desde o início porque só cria aplicações novas, sem nada vivo para adotar.

`argocd/apps/satellites/delivery`, sincronizado por `satellites-delivery`, segue o mesmo desenho para os objetos do Kargo por satélite. Adicionar um satélite passa de "escrever um arquivo novo" para "acrescentar um item à lista"; ver [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md) para o mecanismo geral por trás disso.

O chart de entrega ganhou uma peça que o modelo antigo não tinha: um `Namespace` explícito por satélite (`templates/namespace.yaml`).

Esse namespace já nasce com as labels de Pod Security e `kargo.akuity.io/project: "true"`.

Antes, quem criava e rotulava o namespace `<nome>-delivery` era o `managedNamespaceMetadata` do syncPolicy da própria aplicação.

Esse mecanismo só cobre um namespace por `Application`.

Com um chart só emitindo entregas para vários satélites em vários namespaces diferentes, isso deixou de fazer sentido.

O `Namespace` já era liberado no `clusterResourceWhitelist` do projeto de satélites desde sempre, e passou a ser um recurso templável como qualquer outro.

A troca tem um efeito colateral bom: os labels de Pod Security do namespace de entrega passaram a estar escritos num template revisável, em vez de num campo do `syncPolicy` que ninguém lê ao adicionar um satélite. O `managedNamespaceMetadata` continua sendo o mecanismo certo onde ele cabe, que é uma aplicação com um namespace só, como os operadores.

A alternativa nativa do ArgoCD para "um template, várias instâncias" é o `ApplicationSet`, mas ela nunca foi usada neste repositório, e foi descartada de propósito aqui.

Ela adicionaria uma segunda camada de expansão de template com sintaxe `{{ }}` própria, por cima da proteção que a expressão do Kargo já precisa contra o Helm, descrita em [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md).

Duas camadas de `{{ }}` sobre uma terceira sintaxe parecida é risco de colisão real.

Um array em `values.yaml` de um chart Helm local, a mesma convenção que todo componente deste repositório já segue, resolve o mesmo problema com uma única camada de template, já comprovada pelo resto do repositório.

Há uma perda real na escolha: o `ApplicationSet` sabe gerar instâncias a partir do que ele descobre sozinho, varrendo diretórios de um repositório ou repositórios de uma organização, e um array em `values.yaml` exige que alguém escreva o item. Com um satélite consolidado e um punhado em perspectiva, escrever o item é barato, e a decisão merece ser revisitada se algum dia a lista crescer a ponto de a descoberta automática compensar a camada extra.

O `satellites-delivery` e o `satellites-launcher` agora são as únicas aplicações genéricas de satélites. O blog aparece uma vez em cada lista: o launcher emite a `Application` `blog`, e o delivery emite o projeto, o `Warehouse`, o `Stage` e o `ProjectConfig` de `blog-delivery`.

A aplicação `satellites-delivery` tem `automated` com `selfHeal`, `prune` e `allowEmpty: false`. Assim, mudanças no chart genérico e nos itens de `values.yaml` são reconciliadas pelo Argo CD sem depender de uma sincronização manual.

O projeto do Kargo é cluster-scoped por definição do CRD. Por isso o template de `project.yaml` não possui `metadata.namespace`; o namespace `blog-delivery` é criado separadamente e concentra os recursos namespaced do projeto, como `Warehouse`, `Stage` e `ProjectConfig`. Adicionar um namespace ao `Project` seria inválido, não uma correção.

O item do blog possui duas assinaturas no mesmo `Warehouse`, uma para a imagem do frontend e outra para a imagem Laravel. O mesmo `Stage` promove os dois digests para os caminhos Helm correspondentes da `Application` `blog`.

O `Warehouse` do Kargo para o blog acompanha a tag `main`, e não a tag de commit mais nova.

Ele faz isso com a estratégia `Digest`, não com a tag `sha-<commit>`.

A diferença importa porque uma tag é só um nome que o registry aceita mover: com a estratégia de digest, o parâmetro gravado na `Application` é `main@sha256:...`.

Assim, o que roda é exatamente a imagem que a CI do blog publicou e escaneou naquele momento. Um push posterior da mesma tag vira `Freight/Promotion` novos, visíveis no Kargo e no histórico da aplicação, em vez de uma troca silenciosa no próximo pull.

O mecanismo inteiro está em [Rollout de imagens](rollout-de-imagens.md).

## Os componentes de plataforma

Os parágrafos abaixo descrevem, um a um, os componentes de `platform/` que não têm página própria na arquitetura. O [ingress](ingress.md), o [rollout de imagens](rollout-de-imagens.md) com o Kargo e a camada da [Cloudflare](opentofu.md) têm as suas.

O que aparece aqui, portanto, não é a lista completa da camada de plataforma, e sim o que não coube em outro lugar. Cada bloco segue a mesma ordem: onde o componente mora, o que ele resolve e qual decisão dele custou mais caro para chegar ao formato atual.

### Identidade: Keycloak

A identidade vive no Keycloak, em peças com responsabilidades separadas.

O servidor é um `StatefulSet` escrito à mão em `argocd/apps/platform/keycloak`, no mesmo molde do Portainer.

Ele leva a imagem oficial 26.7.4 por digest, um pod só, `securityContext` endurecido e sem token de `ServiceAccount`, porque o processo não fala com o Kubernetes.

Ele roda `kc.sh start` sem `--optimized`, então refaz a configuração a cada início, alguns segundos a mais que não pesam num único pod.

O cache interno fica em modo `local`, porque não há segundo pod com quem formar cluster.

A conexão vem do `Secret/keycloak-postgres-app`, replicado pelo `ClusterSecretStore/data-secrets` a partir do slot `a` selecionado no namespace `data`. O Laravel usa o mesmo mecanismo com `portfolio-postgres-app`. Os Secrets de origem legados foram removidos após a validação, e cada aplicação mantém dois slots de login para rotação e rollback. A role proprietária de cada banco não aceita login.

O cluster compartilhado fica em `argocd/apps/data/shared-postgres` e declara `instances: 1`. O failover do operador não se aplica aqui: não há réplica para promover quando a primária cai. A proteção que sobra é o reinício automático do pod pelo Kubernetes sobre o mesmo volume, que sobrevive pela retenção do provisionador, não por existir uma segunda cópia do dado. Um segundo nó mudaria esse cálculo: com um nó só, mais instâncias protegeriam o processo, não o host onde o volume mora.

| Banco | Roles de aplicação | Secrets de origem | Namespace consumidor |
| --- | --- | --- | --- |
| `portfolio` | `portfolio_a`, `portfolio_b` | `portfolio-postgres-app-a`, `portfolio-postgres-app-b` | `blog` |
| `keycloak` | `keycloak_a`, `keycloak_b` | `keycloak-postgres-app-a`, `keycloak-postgres-app-b` | `keycloak` |

O bootstrap do cluster cria o banco inicial do portfólio. Os objetos `Database` e `DatabaseRole` declarados no chart criam e mantêm os dois bancos, as roles proprietárias e os quatro slots de aplicação sem reutilizar a credencial de superusuário.

As variáveis `KC_HOSTNAME/KC_HOSTNAME_ADMIN` separam o nome público do console de administração.

O nome público é `auth.guesant.net`, e o console é `keycloak.guesant.internal`.

O operator oficial do Keycloak chegou a rodar aqui, vendorizado no repositório porque o projeto não publica chart Helm. Ele saiu porque só gerava o `StatefulSet` e o `Service` a partir de um CR, com uma JVM inteira reservando memória para reconciliar um objeto que quase nunca muda, num node em que a memória é o recurso mais disputado; realms, clients e usuários já eram do OpenTofu.

O `StatefulSet` declarado no chart reproduz o que o operator gerava, e o único papel dele que precisou de substituto foi o administrador de bootstrap.

| Elemento | Detalhe |
| --- | --- |
| Mecanismo | O pod lê, por `envFrom` opcional, um `Secret` `keycloak-bootstrap-admin` |
| Variáveis | `KC_BOOTSTRAP_ADMIN_USERNAME` e `KC_BOOTSTRAP_ADMIN_PASSWORD` |
| Quando o Keycloak usa | Só quando o realm `master` ainda não tem usuário nenhum |
| Num banco já populado | O `Secret` nem precisa existir |
| Num cluster nascendo vazio | Criado como `SopsSecret` antes do primeiro `apply` de `tofu/keycloak-master`, aposentado por `just keycloak-bootstrap-admin` |

O [runbook de restauração](../operacional/restaurar-o-node.md) descreve esse ciclo do administrador de bootstrap em detalhe.

Os realms são declarados inteiros no git pelos módulos [`tofu/keycloak-*`](opentofu.md): `master/homelab/management`, respectivamente para o Keycloak, o blog e as ferramentas internas.

Não há mais `KeycloakRealmImport`: além de rodar uma vez só, a importação do operator criava o realm sem os escopos padrão do Keycloak (`profile/email/basic` e os demais).

Um token emitido ali não carregava nem o `sub`.

O realm `homelab` original foi recriado pelo Tofu por esse motivo.

Perder o banco custa sessões, não configuração: os `apply` desses módulos recriam tudo.

Não sobrou nenhum `SopsSecret` na aplicação do Keycloak: o login é nativo (senha mais TOTP), sem provedor externo nem e-mail real.

O segredo do client `blog` vive no `SopsSecret/app-secret` do próprio blog.

O blog monta esse segredo em `/secrets/app` e faz o login do `/admin` pelo realm de blog.

Os usuários de cada realm não estão no git.

O operador os cria no console, entrando como o `admin` do `master`.

Ele os coloca no grupo `admins`.

Os clients recebem esse grupo no claim `groups` e usam isso como única regra de autorização.

Senha e TOTP ficam só no Keycloak.

Para fora, só `auth.guesant.net` existe, pelo túnel.

Só os caminhos `/realms` e `/resources` são expostos por esse túnel.

O console de administração responde em `https://keycloak.guesant.internal`, só pela tailnet e pelo [ingress](ingress.md).

Ele usa o `admin` permanente do `master` que o OpenTofu declara.

Argo CD e Grafana ficam em `argocd.guesant.internal` e `grafana.guesant.internal`, pelo mesmo caminho, ambos só com o login do Keycloak.

### Login único: `sso`, oauth2-proxy e Reloader

Os segredos de login único ficam em `argocd/apps/secrets/platform/sso`: um `SopsSecret` por consumidor, criado no namespace dele.

Isso cobre `grafana-oidc/monitoring` e `argocd-oidc/argocd`.

O segredo em `argocd` leva o label `app.kubernetes.io/part-of: argocd` que o Argo exige para ler um Secret por referência.

Essa referência tem o formato `$nome:chave`.

São os mesmos client secrets que o módulo [`tofu/keycloak-management`](opentofu.md) aplica no realm de ferramentas internas, então ambos os lados mudam juntos numa rotação.

A `Application` não cria namespace: ela só coloca segredos onde já existe quem os consome.

O `oauth2-proxy`, em `argocd/apps/platform/oauth2-proxy`, é o login dos serviços que não têm o seu. Seu `SopsSecret` fica em `argocd/apps/secrets/platform/oauth2-proxy`.

É um processo pequeno, sem raiz gravável e sem token de `ServiceAccount`.

O client secret e o segredo do cookie ficam no próprio `SopsSecret` do chart, com a anotação do Reloader para reiniciar quando eles mudarem.

Como o Traefik o consulta a cada requisição, e por que o `Deployment` do Traefik usa `Recreate`, está descrito em [Ingress](ingress.md).

Ele estar no caminho de toda requisição desses serviços faz dele uma dependência dura: se sair do ar, o Prometheus, o Alertmanager, o Hubble UI e o Dashy ficam inacessíveis mesmo saudáveis, porque o Traefik nega quem não tem sessão.

Em troca, nenhum desses quatro precisa ganhar login próprio, e o grupo `admins` do Keycloak continua sendo o único lugar onde o acesso é concedido ou retirado.

O Reloader, em `argocd/apps/platform/reloader`, fecha um buraco do modelo "git como fonte da verdade": um `Secret` que muda no cluster não alcança um processo que o leu por variável de ambiente na criação do contêiner.

O Reloader assiste `Secret/ConfigMap` e reinicia o `Deployment` anotado quando algum deles muda.

A anotação usada é `reloader.stakater.com/auto`.

O Grafana foi o primeiro a pedir isso, pelo client secret do OIDC.

Sem ele, uma rotação declarada no git só valeria depois de alguém reiniciar o pod à mão, e o Argo não faria isso sozinho porque o `Deployment` em si não mudou.

### Portainer e Dashy

O Portainer, em `argocd/apps/platform/portainer`, é uma interface de administração do cluster alcançável só pelo ingress da tailnet. Seu `SopsSecret` fica em `argocd/apps/secrets/platform/portainer`.

Ele não usa o chart oficial: o chart não expõe `securityContext`, e a imagem sobe como root por padrão, então as políticas de admissão recusariam o pod.

Os manifestos são próprios e curtos, com o processo como usuário sem privilégio, sistema de arquivos raiz somente leitura, `drop: ALL`, um volume para o banco dele, a porta do túnel de agentes Edge desligada e a porta HTTP interna servida ao Traefik, que termina o TLS.

Ele recebe `cluster-admin` pela `ServiceAccount`, porque é para isso que existe; a política de rede dele só admite ingresso do host, onde o Traefik roda, e egresso para o API server e o DNS.

As sondas usam `/api/system/status`, o endpoint atual.

O endpoint antigo, `/api/status`, só continua respondendo com um aviso de depreciação.

O administrador local do Portainer nasce com a senha do `SopsSecret/portainer-admin` (`--admin-password-file`), então a janela em que o Portainer trancaria a criação dele não se aplica.

Ele só lê esse arquivo ao criar o administrador, no primeiro start, e é o Job descrito a seguir, não uma pessoa, quem usa essa senha.

O login do dia a dia é pelo Keycloak.

Como as configurações de OAuth do Portainer vivem no banco dele e não em manifesto, um Job de `PostSync` do Argo (`oidc-job.yaml`) as aplica pela API a cada sync.

| Parâmetro do Job de OIDC | Valor |
| --- | --- |
| Client | `portainer`, do realm `management` |
| Identificador | `preferred_username` |
| Segredo do client | `SopsSecret` `portainer-oidc` |
| Administrador criado | Nome vem de `OPERATOR_USERNAME`, precisa bater com o usuário do console |

O Job aplica uma URL de logout que leva o `client_id`.

Isso é necessário porque o Keycloak recusa um `post_logout_redirect_uri` sem `id_token_hint`, nem sem o próprio client_id, e Portainer e Grafana não enviam o primeiro desses parâmetros.

O mesmo Job garante que o usuário do operador exista como administrador.

A edição livre do Portainer não associa times automaticamente pelo token, por isso o usuário é criado pelo Job em vez de deixar o OAuth criá-lo sem papel.

Ela também não envia PKCE (o client dele no realm é o único sem essa exigência) e não esconde o formulário de usuário e senha da tela de login, que continua ao lado do botão do Keycloak, protegendo o `admin` local só com a senha, longa e cifrada, que ninguém digita.

O Dashy, em `argocd/apps/platform/dashy`, é a página inicial dos nomes internos: um painel estático com um cartão por serviço, inclusive o Hubble UI do Cilium, ligado nos values da role `cilium` e servido em `hubble.guesant.internal`.

O próprio Dashy é servido por ambos os repositórios, este e o do blog, em `guesant.internal/dashy.guesant.internal`.

O painel inteiro é um `ConfigMap` montado como o `conf.yml` do Dashy.

Assim, adicionar um serviço é um commit, não um clique.

O grupo `guesant.net` também reúne os endpoints públicos do projeto: `guesant.net`, `auth.guesant.net`, `admin.guesant.net` e `api.guesant.net/docs`. Eles ficam separados dos serviços internos para que o dashboard continue sendo um índice útil tanto para a operação na tailnet quanto para os endereços públicos do site.

A edição pela interface, a gravação em disco e a verificação de versão nova (a única saída para a Internet que ele tentaria) ficam desligadas na própria configuração, e o pod roda como o usuário `node` da imagem, com raiz somente leitura e sem token de `ServiceAccount`.

Ele não faz verificação de status dos serviços, porque os nomes internos só resolvem na tailnet, não dentro do cluster, e apontar as verificações para os `Service` exigiria abrir a política de rede de cada namespace para um painel.

### Observabilidade

A observabilidade continua definida em `argocd/apps/platform/monitoring`, mas está desligada por padrão para preservar CPU e memória no Raspberry Pi. O flag raiz `enabled: false` controla o wrapper Helm inteiro, incluindo o kube-prometheus-stack, o Grafana, o Prometheus, o Alertmanager, os exporters e o blackbox exporter.

Os templates próprios de `Probe` e `PrometheusRule` também são condicionais. Quando o flag está desligado, eles não são renderizados e o Argo remove os recursos namespaced que pertenciam à stack. A `Application` usa `allowEmpty: true` para autorizar explicitamente esse estado vazio, já que o comportamento padrão do Argo impede uma sincronização que apagaria todos os recursos gerenciados.

A configuração anterior de coleta, retenção, alertas, autenticação do Grafana e sondas permanece nos values para que a stack possa ser reativada alterando apenas `enabled` para `true`. Enquanto estiver desligada, Grafana, Prometheus, Alertmanager e os endpoints internos de monitoramento não ficam disponíveis.

O namespace `monitoring` e as CRDs do operador podem continuar existindo como infraestrutura declarada, mas não há workloads de observabilidade rodando nele. Isso permite reativar a stack sem recriar os contratos do cluster e elimina o consumo contínuo dos pods de coleta e visualização.

O ingress acompanha esse mesmo estado. As HTTPRoutes de Grafana, Prometheus e Alertmanager, o middleware de autenticação do namespace `monitoring` e o `ServiceMonitor` do Traefik são condicionais ao flag da stack. Assim, a desativação não deixa rotas apontando para Services inexistentes nem objetos de coleta sem consumidor.

### Armazenamento

O armazenamento tem uma classe só.

`argocd/apps/platform/storage` instala o provisioner `local-path` do Rancher, o manifesto oficial vendorizado, na mesma versão que o k3s embutia.

Esse provisioner leva as imagens por digest e `requests/securityContext` endurecidos.

Ele também instala a `StorageClass` `local-path`, padrão do cluster, com `reclaimPolicy: Retain`.

O k3s trazia esse mesmo provisioner como addon `local-storage`, com a classe em `Delete`.

Como a política de reclaim de uma classe é imutável e o k3s reaplica o manifesto do addon a cada reinício, a única forma de ter uma classe `Retain` com o nome padrão foi desligar o addon no `config.yaml` do k3s e passar a classe e o provisioner para o repositório.

O diretório no node continua `/var/lib/rancher/k3s/storage`, e um PV já ligado não depende da classe existir, então a troca não mexeu em nenhum volume.

O app fica em `kube-system` de propósito: o provisioner cria e apaga diretórios por um helper pod que roda como root com uma imagem `busybox`.

As políticas de admissão e o PSS `restricted` recusariam isso em qualquer outro namespace, e `kube-system` já é a exceção declarada delas.

`Retain` significa que apagar um PVC deixa o PV `Released` e o diretório intacto, e religá-lo é o procedimento de [restaurar um volume retido](../operacional/restaurar-um-volume-retido.md); não significa backup, porque o disco é um só.

A distinção vale ser repetida: `Retain` protege contra erro de operação, um prune que apaga o que não devia, e não contra falha de hardware, que levaria o diretório junto. Um provisioner de caminho local também amarra todo volume a este node, o que é irrelevante num cluster de um nó e seria o primeiro obstáculo se um segundo entrasse.

A classe `local-path-retain` que existia antes dentro do chart dedicado do Postgres não existe mais.

Os dados do portfólio e do Keycloak agora usam o volume do cluster compartilhado `postgres`, declarado em `argocd/apps/data/shared-postgres`. O provisioner `local-path` tem política `Retain`, e a retenção protege o volume contra remoção acidental do PVC, sem substituir backup.

A classe antiga foi removida depois da migração para o cluster compartilhado e da validação dos consumidores. Não há mais um cluster CNPG dedicado por aplicação no repositório.

### Políticas de admissão

As políticas de admissão ficam em `argocd/apps/platform/admission-policies`, como `ValidatingAdmissionPolicy` nativas do Kubernetes, e não num Kyverno ou Gatekeeper: as regras (imagem por digest, registry permitido e `securityContext` endurecido) cabem em expressões CEL avaliadas pelo próprio API server, sem um controller a mais para manter, atualizar e que, se cair, derruba a criação de pods junto.

Elas valem para todo namespace menos o `kube-system`, onde o Cilium precisa de privilégio e o k3s traz CoreDNS e local-path-provisioner por tag.

Como o `ValidatingAdmissionPolicy` é de escopo de cluster, o projeto `infra` o libera no `clusterResourceWhitelist`.

As regras nasceram direto em `Deny` depois de conferir que nenhum pod vivo as violava; um pod que já roda não é reavaliado, então uma violação só aparece quando o controller tenta criar o próximo, como um `ReplicaSet` preso sem pods.

A `Application` delas está na onda `0`, junto dos operadores, e não depois dos workloads.

O `root` só avança para a onda seguinte quando a anterior está saudável, então uma política que só fosse aplicada depois de um workload que depende dela (uma imagem de um registry recém-adicionado à lista, por exemplo) travaria tudo, o workload recusado pela política antiga e a política nova esperando o workload ficar saudável. Foi exatamente o que aconteceu ao ligar o Grafana, e a onda `0` é o que impede a repetição.

### Benchmark CIS

O benchmark CIS do node roda toda semana, no horário do `CronJob` de `argocd/apps/platform/kube-bench`, com a imagem oficial do kube-bench pinada por digest e o perfil `k3s-cis-1.9`.

Ele é restrito às checagens de `policies` (RBAC, ServiceAccounts, Pod Security e políticas de rede).

As seções de master e node ficam de fora de propósito: no k3s, o API server e o kubelet rodam dentro do processo `k3s`, e o perfil lê os argumentos deles com `journalctl`, que não existe na imagem.

Por isso, dentro de um pod essas checagens reportam falhas que não são reais, como `anonymous-auth` ligado quando o node usa `anonymous-auth=false`.

Com esse recorte o Job não precisa de `hostPID` nem de montagem do host: roda sem root, com sistema de arquivos raiz somente leitura.

Ele fica num namespace próprio com Pod Security `restricted`, declarado no mesmo chart de namespaces do projeto `infra` que rotula o `blog`.

Ele também leva uma ClusterRole só de leitura sobre pods, ServiceAccounts, namespaces, RBAC e `NetworkPolicy`, sem acesso a `Secret`.

O resultado fica no log do Job até o `ttlSecondsAfterFinished` declarado no `CronJob` expirar.

`kubectl -n kube-bench create job --from=cronjob/kube-bench kube-bench-manual` roda o benchmark fora do agendamento.

## A política de sincronização padrão

Todo `Application` deste repositório, o root incluído, carrega o mesmo bloco de `syncPolicy`, e o modelo em [adicionar um satélite novo](../operacional/adicionar-um-satelite.md) já vem com ele. Cada opção resolve um problema concreto do Argo em operação automática.

O bloco ser idêntico em toda parte é o que dá valor a ele: uma aplicação que precise de algo diferente passa a ser uma exceção visível no diff, em vez de mais uma variação entre muitas. Os dois parágrafos abaixo percorrem as opções pelo problema que cada uma evita, que é a forma de decidir se uma exceção futura se justifica.

| Opção de `syncPolicy` | O que evita |
| --- | --- |
| `ServerSideApply=true` | Limite de tamanho da annotation `last-applied-configuration` em CRDs grandes; deixa o Argo dono só dos campos que ele declara |
| `FailOnSharedResource=true` | Duas `Application` brigando indefinidamente pelo mesmo recurso |
| `PruneLast=true` | Uma migração ficar sem o recurso velho no meio do caminho, ao adiar a remoção do que saiu do git |
| `PrunePropagationPolicy=foreground` | Um resultado de sincronização não observável, ao esperar os dependentes sumirem antes de dar o pai como removido |

`ServerSideApply=true` faz o Argo aplicar por server-side apply, o mesmo modo que as roles Ansible usam nos charts.

`PrunePropagationPolicy=foreground` faz um `Deployment`, por exemplo, só ser dado como removido depois dos seus pods.

O bloco `retry` com backoff crescente e um teto de tentativas cobre o caso comum de uma sincronização falhar só porque um webhook de admissão ou uma CRD ainda estava subindo; sem ele, a `Application` fica em erro até alguém clicar em sync.

`allowEmpty: false` impede que um diretório vazio por engano (um `git mv` mal feito, uma branch errada) apague tudo o que a `Application` gerencia.

`revisionHistoryLimit` mantém só as últimas revisões para rollback, o suficiente para desfazer uma sincronização ruim sem acumular histórico no estado do Argo.

## Gate de deriva zero

Nenhum `Application` novo entra com `automated` ligado de primeira.

A regra é que ele nasce com sincronização manual, o operador roda `argocd app diff` (ou `kubectl diff` sobre a renderização) até o resultado ser vazio, e só então o `syncPolicy.automated` entra no manifesto.

A razão é o `prune`: uma aplicação automática com `prune: true` apaga do cluster tudo o que não está no git, e um diff não vazio na primeira sincronização significa que algo vivo no cluster não está no git, ou seja, seria apagado.

A ordem de liberação segue o risco: primeiro as aplicações que só criam recursos novos, depois as que adotam recursos existentes, por último as que gerenciam dados.

Um `Cluster` do CNPG só sai do manual depois de `Prune=false,Delete=false` no próprio recurso, como o guia de satélite descreve.

As aplicações que existiam em `operators/` e `platform/` quando essa regra entrou, incluindo o Argo CD Image Updater que o Kargo depois substituiu, já passaram por esse gate e saíram do outro lado com `automated` ligado.

Nenhuma ficou presa em sincronização manual.

Adotar um recurso já vivo tem uma armadilha própria, o nome do release do Helm. O cert-manager foi o primeiro caso real: o wrapper local precisou declarar o mesmo nome de release que a instalação anterior por Ansible usava, senão o Argo cria objetos paralelos em vez de reconhecer os existentes, porque o nome do release entra no nome de vários recursos do chart.

A consolidação do blog trouxe uma variante do mesmo problema: quando uma aplicação antiga já é gerenciada pelo próprio Argo, ela herda o nome do release do nome dela mesma, sem precisar declarar `helm.releaseName`, então a aplicação nova só adota de forma limpa se receber exatamente o mesmo nome da antiga.

O nome do release não é o único critério. A migração do banco dedicado do blog para o cluster compartilhado mostrou o outro.

Quando a categorização em camadas chegou, o `Cluster` foi promovido para `data/shared-postgres`, junto com os objetos `Database`, `DatabaseRole` e os Secrets de cada consumidor.

O nome da aplicação passou a ser `shared-postgres`, sem manter uma aplicação de dados por consumidor.

Fixar `helm.releaseName: postgres` não resolveu, porque quem decide se uma aplicação pode assumir um recurso já existente é a anotação `argocd.argoproj.io/tracking-id` que o Argo grava em cada um.

Essa anotação leva o nome da aplicação como prefixo, por exemplo `shared-postgres:postgresql.cnpg.io/Cluster:data/postgres`.

Com `FailOnSharedResource=true`, a aplicação nova se recusaria a assumir recursos marcados com o nome antigo. A migração foi concluída antes do cutover, com os consumidores validados contra os Secrets replicados pelo ESO.

Essa reescrita foi seguida de uma sincronização manual, já que o Argo não tenta de novo sozinho uma revisão que falhou.

Renomear uma aplicação que já gerencia recursos exige esse mesmo passo; a alternativa é manter o nome antigo.

Há um caso em que o Kargo grava a tag de imagem resolvida como parâmetro direto na `Application`, pelo passo `argocd-update`, em vez de um commit, sem passar pelo git.

Nesse caso, a aplicação nova precisa declarar esse mesmo parâmetro (`spec.source.helm.parameters`) com o valor atual logo na criação.

Esse parâmetro vive em mais de um dono ao mesmo tempo, o git e o Kargo, então a aplicação `satellites-launcher` declara `ignoreDifferences` para `/spec/source/helm/parameters` da aplicação `blog`.

Essa declaração usa `RespectIgnoreDifferences=true`: sem isso, o `selfHeal` do root devolvia a tag do git a cada reconciliação e desfazia toda promoção de imagem, o que só apareceu quando uma imagem nova do blog ficou presa na tag antiga.

O valor em `blog.yaml` continua sendo o ponto de partida de uma instalação do zero, e vale atualizá-lo quando convém, mas não é mais o que decide a imagem em execução; ele fica para trás assim que o Kargo promove uma imagem nova.

O caminho inverso também é declarado.

Toda `Application` em `argocd/applications` carrega o finalizer `resources-finalizer.argocd.argoproj.io`, então apagar o arquivo dela do git faz o root removê-la e o Argo remover, em cascata, tudo o que ela criou.

Antes do finalizer, o root removia só o objeto da aplicação e os recursos ficavam órfãos no cluster, ainda com a anotação `argocd.argoproj.io/tracking-id` de quem os criou; foi assim com o Image Updater quando o Kargo o substituiu, e a limpeza foi à mão.

O preço da cascata é que ela não distingue um `Deployment` de um banco, por isso o que guarda estado leva `argocd.argoproj.io/sync-options: Prune=false,Delete=false` no próprio recurso.

| Recurso protegido com `Prune=false,Delete=false` | Onde vive |
| --- | --- |
| `Cluster` compartilhado do CNPG | `argocd/apps/data/shared-postgres` |
| `StorageClass` `local-path` | `argocd/apps/platform/storage` |
| Volume do Portainer | `argocd/apps/platform/portainer` |

`Prune=false` cobre o recurso sumir do git com a aplicação viva; `Delete=false` cobre a aplicação inteira sumir.

Os namespaces de `argocd/apps/platform/namespaces` já tinham `Delete=false` pela mesma razão, e o `root` fica de fora do finalizer de propósito: ele é aplicado pelo Ansible, não por outra aplicação, e uma cascata a partir dele apagaria o cluster inteiro.

O sops-secrets-operator é o único caso que pulou o `diff` explícito.

A role `sops_age_key` rodava depois dele em `site.yml`, então a aplicação nunca chegou a sincronizar de verdade.

Ela ficou `Missing` com o namespace `sops` vazio.

Sem nenhum recurso vivo fora do git para comparar, não existe diff possível de rodar; `automated` entrou direto.

A correção da ordem das roles é o que garante que o `Secret` que ele monta já existe na primeira sincronização de verdade.

O `Cluster` compartilhado do CNPG apresentou, por um tempo, uma pista falsa: `kubectl diff` mostrava muitos campos default que o webhook do operador CloudNativePG preenche no objeto vivo (afinidade, `probes/replicationSlots` e outros).

Esses campos são os que o manifesto deste repositório nunca declara.

A investigação real usou o próprio motor de comparação do Argo (`argocd app diff --core`, rodado de dentro do pod `argocd-application-controller`), em vez do `kubectl diff` cru.

Esse motor já normaliza esse tipo de campo webhook-preenchido, e mostrou zero diferença de conteúdo, mesmo com o recurso listado como `OutOfSync` no resumo da aplicação.

Sincronizações reais confirmaram isso na prática: nenhuma tocou em nada, o banco continuou saudável e sem reiniciar. Não existe campo concreto para declarar num `ignoreDifferences`, porque não existe diferença de conteúdo a ignorar; o rótulo `OutOfSync` que fica no resumo dessa aplicação, especificamente para este banco, é uma inconsistência de cache do próprio Argo para este CRD, não um sinal de deriva de configuração.

Confirmado como seguro, `syncPolicy.automated` foi ligado mesmo assim.

## Por que projetos separados, e não um só

A alternativa mais simples seria um único `AppProject` com permissão ampla para tudo. O problema é que isso apagaria justamente a garantia que se quer: que um repositório de aplicação (potencialmente escrito e mantido com menos rigor de revisão do que este repositório de infraestrutura) não consiga, por acidente ou não, tocar em nada além do próprio namespace.

Separar os projetos torna essa garantia parte da configuração do próprio ArgoCD, não uma convenção que depende de disciplina humana para se manter.

## Continue por aqui

[Adicionar um satélite novo](../operacional/adicionar-um-satelite.md) aplica essa separação na prática, com o `just` que escreve a `Application`.

<!-- reviewed: argocd -->
