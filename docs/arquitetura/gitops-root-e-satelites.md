# GitOps: root e satélites

<!-- source-of-trust paths="argocd" -->

O [ArgoCD](../aprender/argocd.md) sincroniza este cluster a partir de um padrão de app-of-apps recursivo, com os projetos `infra` e `satellites`, que têm permissões bem diferentes. App-of-apps recursivo quer dizer que uma aplicação do Argo não descreve um workload, e sim um diretório de outras aplicações, que por sua vez podem descrever mais um: uma única aplicação aplicada à mão no bootstrap basta para o resto do cluster aparecer sozinho.

O projeto ao qual cada aplicação pertence é o que limita o que ela pode criar, e é nessa diferença de teto que se apoia a maior parte das decisões desta página.

O projeto `infra` cobre a infraestrutura definida diretamente neste repositório, com acesso amplo em escopo de cluster: além dos tipos comuns de uma aplicação, ele libera os recursos que um operator de plataforma precisa para se instalar, uma definição de tipo customizado, um papel de cluster e a configuração de armazenamento que o app de storage cria para o provisioner.

| Recurso liberado | Para quê |
| --- | --- |
| [Namespace](../aprender/namespace-do-kubernetes.md), [Application e AppProject](../aprender/argocd.md#application-e-appproject) | Objetos comuns de qualquer aplicação do Argo |
| [CustomResourceDefinition](../aprender/kubernetes-operators.md#crd-e-controller) | Instalação de um operator de plataforma |
| [ClusterRole, ClusterRoleBinding](../aprender/rbac-do-kubernetes.md) | Permissão que o operator precisa fora do próprio namespace |
| Webhook de admissão | Validação que um operator registra no API server |
| [StorageClass](../aprender/modelo-de-armazenamento-do-kubernetes.md) | Criada pelo app de armazenamento para o provisioner |

É nele que vive a aplicação root, aplicada uma única vez pela role de bootstrap correspondente, com fontes múltiplas: a pasta [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications), com sincronização recursiva de diretório ligada, e os arquivos de projeto de [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root). Um arquivo novo colocado ali é detectado e sincronizado pelo Argo sozinho, sem nenhum passo manual, e o mesmo vale para uma mudança num projeto, como liberar um tipo novo na lista de recursos permitidos.

Os projetos entrarem como fonte do root foi uma correção. Antes, eles só mudavam pelo bootstrap do Ansible, e isso fez algumas aplicações falharem a sincronização no mesmo dia: o Argo tentava aplicar um tipo que o projeto ainda não liberava, esgotava as tentativas e parava.

Os projetos em `argocd/root` levam a mesma proteção contra remoção descrita mais adiante, na seção sobre a política de sincronização padrão, porque o root roda dentro do projeto de infraestrutura e não pode apagar o projeto do qual depende. O arquivo do próprio root continua fora dessa fonte e só muda pelo bootstrap, para que um erro nele não consiga desfazer o próprio root.

O projeto `satellites` é deliberadamente restrito: só pode criar recursos de escopo de namespace, com um pequeno conjunto de exceções liberadas explicitamente.

| Exceção liberada | Motivo |
| --- | --- |
| [Namespace](../aprender/namespace-do-kubernetes.md) | Um satélite precisa poder existir no próprio namespace |
| [StorageClass](../aprender/modelo-de-armazenamento-do-kubernetes.md) | Usada pelo volume do Postgres do blog |
| `Project` do Kargo | Ver [rollout de imagens](rollout-de-imagens.md) |

Uma aplicação sob esse projeto não consegue criar um papel de cluster ou uma [definição de tipo customizado](../aprender/kubernetes-operators.md#crd-e-controller), mesmo que o operador do Argo quisesse; a permissão simplesmente não existe no projeto. Isso significa que qualquer coisa declarada sob `satellites` nunca pode, por engano, escalar para um recurso de cluster inteiro.

O que define esse teto de permissão é o projeto declarado na própria aplicação, não o repositório que a declara: uma aplicação sob `satellites` fica igualmente restrita apontando para este repositório ou para um repositório de terceiro.

Existe ainda o projeto `default`, que o próprio ArgoCD cria na instalação com permissão total; um arquivo deste repositório o sobrescreve com listas vazias de repositórios, destinos e recursos permitidos. Sem isso, a restrição do projeto de satélites seria contornável um nível abaixo: uma aplicação sob esse teto não pode criar recurso de cluster, mas uma aplicação filha declarando o projeto padrão poderia.

Com o projeto padrão fechado, uma filha que esqueça de declarar o projeto de satélites simplesmente não sincroniza, e o erro aparece no próprio Argo.

Originalmente, cada satélite era ele mesmo outra aplicação de sincronização recursiva de diretório, apontando para uma pasta de GitOps dentro do repositório da própria aplicação; um satélite novo, de terceiros, ainda segue esse formato, descrito no guia [adicionar um satélite novo](../operacional/adicionar-um-satelite.md). O único satélite que existe hoje, o blog, não segue mais esse formato. A mudança não aposentou o padrão: ela reconheceu que, com um operador só cuidando dos dois repositórios, o custo da separação não estava comprando nada.

A seção seguinte explica esse caso e deixa claro o que continuaria valendo se um segundo repositório, com outro dono, entrasse na jogada.

## Por que o blog não é um satélite de verdade

O blog, servido em `guesant.net`, só parece um satélite comum à primeira vista. As peças que ele precisa no cluster, o app em si, o túnel Cloudflare, as políticas de rede do namespace e o projeto de entrega do Kargo, vivem direto neste repositório, sob o projeto `satellites`, com o mesmo teto de permissão de qualquer satélite. O repositório da aplicação em si não declara nenhum objeto do Argo.

A razão não é técnica, é organizacional: como o mesmo operador administra ambos os repositórios, separar "o que é infraestrutura" de "o que é aplicação" em repositórios diferentes não reduz risco algum, só multiplica onde uma mudança de deploy precisa ser feita. O padrão de satélite continua existindo e documentado para o cenário em que ele resolve um problema real, um futuro colaborador ou uma automação com acesso de escrita só ao repositório da aplicação, não a este.

O banco do blog é a exceção a essa organização por pasta: apesar de ser exclusivo do blog e sincronizar sob o mesmo projeto `satellites`, mora na camada de dado do repositório, porque essa camada agrupa todo dado com estado, dedicado ou compartilhado, separado do resto da aplicação que o consome; veja a tabela na seção seguinte.

Esse banco não tem segredo cifrado próprio hoje: o backup em object storage que precisaria de credenciais está desligado de propósito, veja [estado fora do git](../operacional/estado-fora-do-git.md). O critério que separa a pasta do satélite da camada de dado é a política de remoção, não a titularidade: um banco exclusivo de uma aplicação continua sendo dado, e dado sai do cluster por um caminho mais conservador do que o resto.

Manter as duas coisas na mesma pasta convidaria a aplicar a elas a mesma política de remoção, que é exatamente o erro que a separação evita.

O app e o cloudflared rodam cada um com uma identidade própria, criada pelo chart, sem token da API montado, porque nenhum dos processos fala com o Kubernetes, e com o sistema de arquivos raiz somente leitura. O app escreve só nos volumes declarados: um volume efêmero para arquivos temporários e para os assets públicos, e um volume persistente onde o tectonic guarda o bundle LaTeX pesado que baixa uma vez para gerar o PDF do currículo.

Num volume efêmero esse cache morria a cada réplica nova e, com a variável que restringe o tectonic a rodar só com cache já pronto, a geração falhava sempre por não achar o formato; a configuração do chart desliga essa trava e o volume persiste o download.

O sops-secrets-operator segue o mesmo padrão de endurecimento, com o `securityContext` do chart ligado: seccomp `RuntimeDefault`, sem root, sem escalada e sem capabilities. Ele é a única peça desta lista que precisa de um token de ServiceAccount, porque o trabalho dele é justamente escrever segredos no cluster a partir do que está cifrado no git.

Endurecer o resto do pod importa mais nesse caso, e não menos, já que um processo com esse acesso é o alvo mais atraente do namespace.

O schema do banco do blog nunca é tocado pelo processo web. O chart declara um Job de pré-sincronização que roda, na mesma imagem e com o mesmo segredo do CNPG, a migração da imagem que vai entrar, e o Argo só troca a implantação depois que ele termina, como descrito em [Rollout de imagens](rollout-de-imagens.md).

Durante a transição para a imagem Laravel, o Job aceita tanto o bundle de migrações do EF Core legado quanto a migração nativa do Laravel, dependendo de qual imagem está de fato entrando.

Um detalhe do chart já custou um sync: o template do Job escreve o comando como texto simples, não como lista YAML, então um comando com argumentos vira um único executável inexistente; por isso o Job declara o interpretador de shell como comando e o script de fato como argumento, que o chart serializa corretamente.

Como um hook não conta como deriva, uma mudança só no Job não dispara o sync automático; ela entra no próximo sync real, ou num sync pedido à mão.

Todo namespace criado por uma aplicação recebe os mesmos labels de Pod Security restrito, aplicação, aviso e auditoria. Nos operadores, isso vem da metadata de namespace gerenciada pela própria política de sincronização da aplicação. O namespace do blog, com os mesmos labels, é declarado à parte, numa aplicação do projeto `infra` sem permissão de remoção, para que nenhuma remoção em cascata vinda do satélite apague o namespace com tudo dentro.

O `kube-system` fica de fora, porque o Cilium e os componentes do k3s precisam de privilégio, e o job de segurança de Pod da CI falha se um namespace novo nascer sem o label de aplicação.

Cada peça que precisa de segredo declara o próprio `SopsSecret` no chart wrapper local, e nenhuma delas pelo mecanismo antigo, removido junto com o controller que o cifrava.

Um template guarda o client secret do login do admin pelo realm `homelab` do Keycloak, entregue ao app como arquivo montado, e não como variável de ambiente, que vazaria para qualquer processo filho e para dumps do processo; o app lê o diretório segredo por segredo, e a identidade do grupo do pod deixa os arquivos legíveis só para o usuário do app.

Outro template guarda o token do túnel; as regras de ingress do túnel não moram mais no chart, e sim na própria Cloudflare, declaradas em [OpenTofu: a camada da Cloudflare](opentofu.md).

### Políticas de rede

O [Cilium](../aprender/cilium-e-calico-como-cni.md) roda em modo de aplicação sempre ativa, em que todo pod nega por padrão qualquer tráfego que nenhuma política libere, com ou sem política própria. Por isso cada namespace tem uma política de rede do Cilium que lista o que ele de fato usa, levantado nos veredictos de auditoria do Hubble.

A aplicação de políticas de rede do projeto `infra` cobre os namespaces de plataforma: DNS para o CoreDNS, API server, entrada vinda do host e do API server para sondas, métricas e webhooks, saída para o GitHub e os registros de imagem, e o CNPG falando com o Postgres do blog.

O chart de políticas do blog ganha as de saída do próprio namespace, incluindo o cloudflared alcançando o Keycloak, porque o domínio de autenticação entra pelo mesmo túnel do blog e é roteado direto para o servidor, sem passar pelo app; essa regra ficou bloqueada por um tempo por um seletor de rótulo que não batia com o pod real, até o rótulo ser corrigido.

Desde que o modo de auditoria foi desligado (ver [checklist de segurança](checklist-de-seguranca.md)), essas regras bloqueiam de verdade o que não liberam, não só registram.

O namespace do blog é o único do cluster com mais de um mecanismo de política de rede ao mesmo tempo, e não por uma migração pela metade. O ingress vem de uma política de rede nativa do Kubernetes, enquanto o egress e a linha de base ficam com a política própria do Cilium.

Ambos convivem de propósito, e depurar conectividade nesse namespace exige olhar os dois tipos de recurso, porque cada um só enxerga a metade do tráfego que declara.

O endpoint de saúde do próprio Cilium também cai nessa mesma regra de negação: o ping que o agente faz nele a partir do host seria descartado, e o próprio Cilium passaria a reportar o node como inalcançável, sem que nenhum pod perdesse tráfego. Como esse endpoint não pertence a namespace nenhum, a liberação é uma política de escopo de cluster do próprio Cilium, e o projeto `infra` libera esse tipo de recurso.

O caso ilustra bem o preço de negar por padrão: o que quebra primeiro não é o tráfego da aplicação, que alguém pensou em liberar, e sim a checagem interna que ninguém lembrou de declarar. Liberar o node remoto junto do host local, mesmo num node só, evita que a mesma regra precise ser revisitada quando um segundo node entrar.

## Como a pasta de applications é organizada

Dentro de `argocd/applications`, cada subpasta corresponde a uma camada, e a camada define a onda de sincronização (`argocd.argoproj.io/sync-wave`) que todo arquivo dentro dela carrega. O Argo aplica as ondas em ordem crescente e só avança para a próxima quando todos os recursos da onda anterior estão saudáveis, então a camada é o que garante que um satélite nunca sincronize antes de uma dependência de plataforma que ele precise.

A distância entre as ondas é deliberada: sobra espaço para inserir uma camada intermediária no futuro sem renumerar o que já existe.

| Pasta | Onda | O que vive ali |
| --- | --- | --- |
| `operators/` | `0` | Controllers que gerenciam CRD ou recurso de outro componente: cert-manager (certificados), CNPG (`Cluster` do Postgres) e o sops-secrets-operator (`SopsSecret`); todos no projeto `infra` |
| `platform/` | `0` | Ferramentas de plataforma de uso direto, que não existem para gerenciar CRD de outra coisa: o Kargo, que promove imagens dos satélites editando a própria `Application` do Argo (veja [Rollout de imagens](rollout-de-imagens.md)), os namespaces, as políticas de rede, o kube-bench, as políticas de admissão, o [ingress](ingress.md) (Traefik com Gateway API, as `HTTPRoute` dos nomes internos e a CA interna), o Portainer, o Dashy, o Reloader, os segredos de OIDC (`sso`) e o `oauth2-proxy`; também no projeto `infra` |
| `data/` | `1` | Dado com estado, dedicado a um único satélite ou compartilhado entre vários, mantido fora da pasta do satélite que o usa; hoje só `blog-postgres`, o `Cluster` do CNPG do blog, no projeto `satellites` porque é dado exclusivo dele, não infraestrutura de plataforma |
| `satellites/<nome>/` | `0` a `3` | As `Application` de um satélite consolidado neste repositório, no projeto `satellites`; hoje só `satellites/blog/`, com onda própria por peça (rede na onda `0`, antes do app na `2`, antes do túnel na `3`) |
| `satellites/launcher/` e `satellites/delivery/` | `0` e `1` | Exceção à regra de uma pasta por satélite: charts com array de instâncias em `values.yaml`, descritos na seção seguinte |

Todas essas pastas vêm de um mini chart wrapper em [argocd/apps](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps), organizado nas mesmas categorias, não de um chart upstream apontado direto, para manter os repositórios de origem do projeto `infra` restritos a este único repositório. Os values desses wrappers declaram o pedido e o limite de memória de cada operador, medidos contra o consumo real, e pinam as imagens por [digest](../aprender/pinagem-por-digest-e-hash.md), que o Renovate atualiza junto da tag.

Apontar direto para um chart upstream funcionaria, mas obrigaria a incluir o repositório dele na lista de origens confiáveis, e a partir daí qualquer aplicação do projeto `infra` poderia sincronizar de lá. Manter a lista com um endereço só transforma "de onde este cluster aceita manifesto" numa resposta de uma linha, verificável sem ler cada aplicação.

O app do blog é a exceção com limite de CPU folgado, e não apertado: uma medição mostrou que a cota de meio núcleo segurava a pré-renderização de cada página por tanto tempo quanto o próprio trabalho de renderizar, num node onde nada mais disputa CPU em regime.

O limite subiu para um núcleo inteiro; não ficou sem limite porque o namespace do blog carrega um limite de intervalo que injeta um valor default em todo container sem um declarado, e um pedido maior que esse default torna o pod inválido na criação, como aconteceu na primeira tentativa desta mudança.

A sequência explica por que o limite existe mesmo sem concorrência por CPU: ele não está lá para proteger vizinhos, e sim porque o namespace exige que todo contêiner tenha um. Declarar o valor certo é melhor do que herdar o default, que foi escolhido para um workload qualquer e não para um que renderiza página sob demanda.

A implantação do app roda com a estratégia de recriação, porque só existe uma réplica e o volume persistente do cache de renderização não suporta dois pods montando o mesmo volume ao mesmo tempo. O chart wrapper precisa anular explicitamente o bloco de atualização gradual junto desse tipo, pelo mesmo motivo descrito adiante para o Grafana: o server-side apply do Argo recusa trocar o tipo da estratégia enquanto a implantação viva ainda carrega esse bloco de uma renderização anterior.

A sonda de prontidão do app aponta para um caminho diferente da sonda de vida, que só confirma que o processo está de pé.

A diferença importa num rolling update: a sonda de vida responde assim que o processo sobe, mesmo antes do pool de conexão com o Postgres existir, e o Service já mandaria tráfego real para um pod cuja primeira leitura de conteúdo falha; a sonda de prontidão roda uma consulta mínima contra o banco, com um teto de tempo próprio, e só devolve sucesso depois que essa conexão responde de verdade.

O timeout da sonda em si existe para não competir com esse teto interno: sem essa folga, o próprio Kubernetes derrubaria a sonda por timeout antes da consulta ter chance de responder.

A divisão entre operadores e plataforma existe porque cada um falha de forma diferente: um operator que sai do ar deixa objetos que ele já criou sem reconciliação, enquanto uma ferramenta de plataforma que sai do ar só perde a própria função.

A camada de dado fica fora da pasta do satélite mesmo quando o dado é exclusivo dele, porque o teto de permissão de dado é sempre mais conservador que o do resto do satélite, e misturá-los nivela o mais restritivo pelo menos restritivo por engano. As três camadas respondem, no fim, a uma pergunta só: o que sobra se esta peça sumir do git amanhã.

Some um operator e ficam objetos sem quem os reconcilie; some uma ferramenta de plataforma e some só ela; some um banco e some o dado, que é o único caso irreversível.

## Satélites e entrega do Kargo: um chart com array, não um arquivo por instância

O padrão de satélite que a receita de adicionar satélite escreve, uma aplicação inteira para um repositório de terceiro, e o de entrega do Kargo que a receita correspondente escreve, um projeto de entrega inteiro para cada satélite que promove imagem, são a estrutura que de fato se repete a cada satélite novo, ao contrário do blog, que é a exceção descrita acima.

Adicionar um satélite continha o mesmo bloco de política de sincronização copiado por inteiro a cada arquivo novo, e adicionar uma entrega continha uma pasta de vários arquivos com nome, namespace e imagem grafados em todos eles; a estrutura em si nunca mudava de um satélite para o outro, só os valores.

Duplicação assim não incomoda enquanto há um satélite; ela cobra na primeira vez que a estrutura precisa mudar, porque a mudança tem de ser repetida em cada cópia, e uma esquecida só aparece quando aquele satélite falha. O que segue é a troca desse molde copiado por um chart que gera as instâncias a partir de uma lista.

Um par de charts resolve isso, um para lançar a aplicação de cada satélite e outro para os objetos de entrega do Kargo dela, cada um com uma lista de satélites no `values.yaml` que o template percorre para emitir uma instância por item; o primeiro é automático desde o início porque só cria aplicações novas, sem nada vivo para adotar.

Adicionar um satélite passa de "escrever um arquivo novo" para "acrescentar um item à lista"; ver [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md) para o mecanismo geral por trás disso.

O chart de entrega ganhou uma peça que o modelo antigo não tinha: um [Namespace](../aprender/namespace-do-kubernetes.md) explícito por satélite, com as labels de Pod Security e o rótulo de projeto do Kargo já nele.

Antes, quem criava e rotulava esse namespace era a metadata de namespace gerenciada pela própria aplicação, um mecanismo que só cobre um namespace por aplicação; com um chart só emitindo entregas para vários satélites em vários namespaces diferentes, isso deixou de fazer sentido, e o namespace, já liberado no projeto `satellites` desde sempre, passou a ser um recurso templável como qualquer outro.

A troca tem um efeito colateral bom: os labels de Pod Security do namespace de entrega passaram a estar escritos num template revisável, em vez de num campo que ninguém lê ao adicionar um satélite. O mecanismo antigo continua sendo o certo onde ele cabe, que é uma aplicação com um namespace só, como os operadores.

A alternativa nativa do ArgoCD para "um template, várias instâncias" é um gerador de aplicações a partir de uma fonte externa, mas ela nunca foi usada neste repositório, e foi descartada de propósito aqui: ela adicionaria uma segunda camada de expansão de template, por cima da proteção que a expressão do Kargo já precisa contra o Helm, descrita em [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md).

Duas camadas de expansão sobre uma terceira sintaxe parecida é risco de colisão real, e um array de um chart Helm local, a mesma convenção que todo componente deste repositório já segue, resolve o mesmo problema com uma única camada de template, já comprovada pelo resto do repositório.

Há uma perda real na escolha: aquele gerador nativo sabe criar instâncias a partir do que ele descobre sozinho, varrendo diretórios de um repositório ou repositórios de uma organização, e um array exige que alguém escreva o item. Com um satélite consolidado e um punhado em perspectiva, escrever o item é barato, e a decisão merece ser revisitada se algum dia a lista crescer a ponto de a descoberta automática compensar a camada extra.

A entrega de satélites nasceu com sincronização manual, ao contrário do lançador de satélites: ela precisou adotar os objetos de entrega do blog, que já viviam no cluster sob a aplicação antiga de entrega, e o [gate de deriva zero](#gate-de-deriva-zero) deste repositório não libera sincronização automática antes desse diff ficar vazio. A migração reetiquetou a identidade de rastreio desses objetos do dono antigo para o novo, sem recriar nenhum recurso nem perder histórico de promoção.

A aplicação antiga e o chart antigo devem sair do repositório só depois de confirmado que nenhum recurso vivo continua sob o nome dela, e ainda estão commitados enquanto essa confirmação não roda; removê-los antes disso, com ambos os lados sincronizando ao mesmo tempo, dispararia uma falha de recurso compartilhado contra os mesmos objetos.

O armazém do Kargo para o blog acompanha a tag `main` com a estratégia de digest, e não a tag mais nova por commit.

A diferença importa porque uma tag é só um nome que o registry aceita mover: com a estratégia de digest, o parâmetro gravado na aplicação prende a imagem exata que a CI do blog publicou e escaneou naquele momento, e um push posterior da mesma tag vira um novo lote de imagem e uma nova promoção, visíveis no Kargo e no histórico da aplicação, em vez de uma troca silenciosa no próximo pull.

O mecanismo inteiro está em [Rollout de imagens](rollout-de-imagens.md).

## Os componentes de plataforma

Os parágrafos abaixo descrevem, um a um, os componentes de `platform/` que não têm página própria na arquitetura. O [ingress](ingress.md), o [rollout de imagens](rollout-de-imagens.md) com o Kargo e a camada da [Cloudflare](opentofu.md) têm as suas. O que aparece aqui, portanto, não é a lista completa da camada de plataforma, e sim o que não coube em outro lugar.

Cada bloco segue a mesma ordem: onde o componente mora, o que ele resolve e qual decisão dele custou mais caro para chegar ao formato atual.

### Identidade: Keycloak

A identidade vive no Keycloak, em peças com responsabilidades separadas. O servidor é uma implantação com estado escrita à mão, no mesmo molde do Portainer: imagem oficial por digest, um pod só, contexto de segurança endurecido e sem token de identidade, porque o processo não fala com o Kubernetes.

Ele refaz a configuração a cada início, alguns segundos a mais que não pesam num único pod, e o cache interno fica em modo local, porque não há segundo pod com quem formar cluster. A conexão com o banco vem de um segredo que o CNPG gera para o cluster de dados próprio, e duas variáveis de ambiente separam o nome público, `auth.guesant.net`, do console de administração, `keycloak.guesant.internal`.

O operator oficial do Keycloak chegou a rodar aqui, vendorizado no repositório porque o projeto não publica chart Helm. Ele saiu porque só gerava o mesmo tipo de implantação a partir de um objeto customizado, com uma JVM inteira reservando memória para reconciliar um objeto que quase nunca muda, num node em que a memória é o recurso mais disputado; realms, clients e usuários já eram do OpenTofu.

A implantação declarada no chart reproduz o que o operator gerava, e o único papel dele que precisou de substituto foi o administrador de bootstrap: o pod lê, por variável de ambiente opcional, um segredo com usuário e senha temporários, que o Keycloak só usa quando o realm `master` ainda não tem usuário nenhum.

Num banco já populado esse segredo nem precisa existir; num cluster nascendo vazio, ele é criado como `SopsSecret` antes do primeiro apply do módulo do Keycloak no Tofu e aposentado por uma receita própria, como o [runbook de restauração](../operacional/restaurar-o-node.md) descreve.

Os realms são declarados inteiros no git pelos módulos correspondentes de [OpenTofu](opentofu.md): `master` só para o Keycloak, `homelab` para o blog, e um terceiro só para as ferramentas internas. Não há mais importação de realm pelo operator: além de rodar uma vez só, ela criava o realm sem os escopos padrão do Keycloak, então um token emitido ali não carregava nem a identidade do sujeito; o realm do blog original foi recriado pelo Tofu por esse motivo.

Perder o banco custa sessões, não configuração: o apply desses módulos recria tudo. Não sobrou nenhum segredo cifrado na aplicação do Keycloak: o login é nativo, senha mais TOTP, sem provedor externo nem e-mail real, e o segredo do client do blog vive no segredo cifrado do próprio blog, que o monta como arquivo e faz o login do painel de administração pelo mesmo realm.

Os usuários de cada realm não estão no git. O operador os cria no console, entrando como o administrador do `master`, e os coloca num grupo, que os clients recebem como claim e usam como única regra de autorização; senha e TOTP ficam só no Keycloak. Para fora, só o domínio de autenticação existe, pelo túnel, e só nos caminhos de realm e recurso.

O console de administração responde só pela tailnet e pelo [ingress](ingress.md), com o administrador permanente do `master` que o OpenTofu declara. Argo CD e Grafana ficam em domínios internos próprios, pelo mesmo caminho, ambos só com o login do Keycloak.

### Login único: sso, oauth2-proxy e Reloader

Os segredos de login único ficam numa aplicação própria: um `SopsSecret` por consumidor, criado no namespace dele, cada um com o rótulo que o Argo exige para ler um segredo por referência. São os mesmos client secrets que o módulo de gestão do [OpenTofu](opentofu.md) aplica no realm `management`, então ambos os lados mudam juntos numa rotação. Essa aplicação não cria namespace: ela só coloca segredos onde já existe quem os consome.

O oauth2-proxy é o login dos serviços que não têm o seu: um processo pequeno, sem raiz gravável e sem token de identidade, com o client secret e o segredo do cookie no próprio `SopsSecret` do chart e a anotação do Reloader para reiniciar quando eles mudarem. Como o Traefik o consulta a cada requisição, e por que a implantação do Traefik usa recriação em vez de atualização gradual, está descrito em [Ingress](ingress.md).

Ele estar no caminho de toda requisição desses serviços faz dele uma dependência dura: se sair do ar, o Prometheus, o Alertmanager, o Hubble UI e o Dashy ficam inacessíveis mesmo saudáveis, porque o Traefik nega quem não tem sessão. Em troca, nenhum desses quatro precisa ganhar login próprio, e o grupo de administradores do Keycloak continua sendo o único lugar onde o acesso é concedido ou retirado.

O Reloader fecha um buraco do modelo "git como fonte da verdade": um segredo que muda no cluster não alcança um processo que o leu por variável de ambiente na criação do contêiner. O Reloader assiste segredos e mapas de configuração e reinicia a implantação anotada quando algum deles muda; o Grafana foi o primeiro a pedir isso, pelo client secret do login único.

Sem ele, uma rotação declarada no git só valeria depois de alguém reiniciar o pod à mão, e o Argo não faria isso sozinho porque a implantação em si não mudou.

### Portainer e Dashy

O Portainer é uma interface de administração do cluster alcançável só pelo ingress da tailnet. Ele não usa o chart oficial: o chart não expõe um contexto de segurança configurável, e a imagem sobe como root por padrão, então as políticas de admissão recusariam o pod.

Os manifestos são próprios e curtos, com o processo como usuário sem privilégio, sistema de arquivos raiz somente leitura, todas as capabilities do kernel derrubadas, um volume para o banco dele, a porta do túnel de agentes remotos desligada e a porta HTTP interna servida ao Traefik, que termina o TLS.

Ele recebe permissão de administrador do cluster pela própria identidade, porque é para isso que existe; a política de rede dele só admite ingresso do host, onde o Traefik roda, e egresso para o API server e o DNS.

O administrador local do Portainer nasce com a senha de um segredo cifrado, passada por um argumento de linha de comando, então a janela em que o Portainer trancaria a criação dele não se aplica; ele só lê esse arquivo ao criar o administrador, no primeiro start, e é um Job de pós-sincronização, não uma pessoa, quem usa essa senha. O login do dia a dia é pelo Keycloak.

Como as configurações de OAuth do Portainer vivem no banco dele e não em manifesto, esse mesmo Job as aplica pela API a cada sync, com o client do realm `management`, o nome de usuário preferido como identificador, e uma URL de logout completa, porque o Keycloak recusa uma URL de logout incompleta e nem Portainer nem Grafana enviam todos os parâmetros sozinhos.

O mesmo Job garante que o usuário do operador exista como administrador, usando o nome de usuário da variável `OPERATOR_USERNAME`, declarada no próprio manifesto.

A edição livre do Portainer não associa times automaticamente pelo token, por isso o usuário é criado pelo Job em vez de deixar o OAuth criá-lo sem papel; ela também não envia PKCE, porque o client dele no realm é o único sem essa exigência, e não esconde o formulário de usuário e senha da tela de login, que continua ao lado do botão do Keycloak, protegendo o administrador local só com a senha, longa e cifrada, que ninguém digita.

O Dashy é a página inicial dos nomes internos: um painel estático com um cartão por serviço, inclusive o Hubble UI do Cilium, e servido por ambos os repositórios, este e o do blog. O painel inteiro é um mapa de configuração montado como o arquivo de configuração do Dashy, então adicionar um serviço é um commit, não um clique.

A edição pela interface, a gravação em disco e a verificação de versão nova, a única saída para a Internet que ele tentaria, ficam desligadas na própria configuração, e o pod roda sem privilégio, com raiz somente leitura e sem token de identidade.

Ele não faz verificação de status dos serviços, porque os nomes internos só resolvem na tailnet, não dentro do cluster, e apontar as verificações para o serviço interno de cada um exigiria abrir a política de rede de cada namespace para um painel.

### Observabilidade

A observabilidade é um wrapper do kube-prometheus-stack e do blackbox exporter. O Prometheus coleta em intervalo curto e raspa o node-exporter, o kubelet, o kube-state-metrics e o próprio API server; os alvos de etcd, controller manager, scheduler e kube-proxy ficam desligados, porque no k3s eles rodam dentro do mesmo processo e não expõem métricas separadas, e o kube-proxy nem existe com o Cilium no lugar.

Ele descarta na origem os histogramas do API server e do etcd e as métricas do cAdvisor que ninguém consulta, porque só o kubelet e o API server respondiam pela maior parte das séries e o consumo de memória encostava no limite do pod; o descarte vive nas regras de relabeling de cada alvo, curtas porque o yamllint limita o tamanho da linha.

Com o descarte em vigor, o limite de memória do pod foi apertado depois de confirmar que o uso real ficava bem abaixo do limite antigo, ainda com folga sobre o consumo observado.

O Grafana fica ligado só para a tailnet, autenticando só pelo realm `management` do Keycloak, sem formulário de login local; quem está no grupo de administradores entra com esse papel, e o administrador local sobrevive só por baixo, para a API. Ele não tem persistência, os dashboards e a fonte de dados chegam por mapa de configuração pelos sidecars, e atualizações, relatórios e cadastro ficam desligados na própria configuração.

A sonda de início é alongada, porque no Raspberry Pi o registro dos plugins no primeiro start demora, e a sonda de vida padrão o matava antes de responder.

A atualização derruba a instância antiga antes de subir a nova, e o limite de memória é mais alto do que o padrão, porque instâncias do Grafana subindo lado a lado estouravam o limite e eram mortas por falta de memória antes de ficarem prontas; a estratégia de recriação não serviu porque o server-side apply do Argo recusa trocar o tipo de estratégia enquanto a implantação viva ainda carrega o bloco de atualização gradual anterior.

O chart gera a senha do administrador aleatoriamente a cada renderização, o que faria o Argo reescrevê-la em todo sync; a aplicação ignora esse campo do segredo correspondente, então a senha criada no primeiro sync fica estável.

Além das regras padrão do chart, um template próprio declara alertas de host (disco, memória, temperatura do processador, reboot, exporter fora do ar), de volume quase cheio e dos endpoints públicos, que o blackbox exporter testa de fora para dentro, pelo túnel, incluindo a validade do certificado. Os alvos são o blog, o site principal e o endpoint de descoberta do realm `homelab` no Keycloak, que só responde com sucesso quando o servidor e o realm estão de pé.

O Alertmanager sobe com o receptor vazio do chart: os alertas aparecem na interface dele e na do Prometheus, e o envio para o Discord espera o webhook.

O namespace de monitoramento é o único fora do `kube-system` com Pod Security privilegiado, porque o node-exporter precisa da rede e do sistema de arquivos do host para medir o node; todo o resto dele segue as mesmas políticas de admissão dos outros namespaces, e a política de rede do namespace só libera DNS, o API server, as portas do kubelet e do node-exporter no host e HTTPS para fora.

### Armazenamento

O armazenamento tem uma classe só. Uma aplicação de plataforma instala o provisioner de caminho local do Rancher (o manifesto oficial vendorizado, na mesma versão que o k3s embutia, com as imagens por digest e o contexto de segurança endurecidos no provisioner) e a [classe de armazenamento](../aprender/modelo-de-armazenamento-do-kubernetes.md) padrão do cluster, com política de retenção.

O k3s trazia esse mesmo provisioner como addon, com a classe em modo de exclusão; como a política de retenção de uma classe é imutável e o k3s reaplica o manifesto do addon a cada reinício, a única forma de ter uma classe retida com o nome padrão foi desligar o addon na configuração do k3s e passar a classe e o provisioner para o repositório.

O diretório no node continua o mesmo de sempre, e um volume já ligado não depende da classe existir, então a troca não mexeu em nenhum volume.

O app fica no `kube-system` de propósito: o provisioner cria e apaga diretórios por um helper pod que roda como root, o que as políticas de admissão recusariam em qualquer outro namespace, e o `kube-system` já é a exceção declarada delas. A política de retenção significa que apagar uma reivindicação de volume deixa o volume liberado e o diretório intacto, e religá-lo é o procedimento de [restaurar um volume retido](../operacional/restaurar-um-volume-retido.md); não significa backup, porque o disco é um só.

A distinção vale ser repetida: reter protege contra erro de operação, uma remoção que apaga o que não devia, e não contra falha de hardware, que levaria o diretório junto. Um provisioner de caminho local também amarra todo volume a este node, o que é irrelevante num cluster de um nó e seria o primeiro obstáculo se um segundo entrasse.

Uma segunda classe de armazenamento que existia antes dentro do chart do Postgres do blog não existe mais.

Os volumes do Keycloak e do Portainer foram recriados na classe padrão (o do Keycloak por outra instância do CNPG que assumiu como primary; o do Portainer por um volume novo com os dados copiados e conferidos por hash), o banco do blog passou a declarar a classe padrão sem precisar recriar o volume dele, e a classe antiga foi apagada do cluster junto com os volumes órfãos que ainda a referenciavam.

Ela existia porque a classe padrão de então estava em modo de exclusão, e uma segunda classe era o único jeito de reter um volume; com a classe padrão já retendo por padrão, ela virou duplicata. Duas classes com a mesma política também são um convite a erro, porque um chart novo escolhe uma delas sem que a diferença signifique nada.

### Políticas de admissão

As políticas de admissão são nativas do Kubernetes, e não de um controlador de terceiro como Kyverno ou Gatekeeper: as regras (imagem por digest, registry permitido e contexto de segurança endurecido) cabem em expressões avaliadas pelo próprio API server, sem um controller a mais para manter, atualizar e que, se cair, derruba a criação de pods junto. Elas valem para todo namespace menos o `kube-system`, onde o Cilium precisa de privilégio e o k3s traz seus próprios componentes por tag.

Como esse tipo de política é de escopo de cluster, o projeto `infra` o libera na lista de recursos permitidos. As regras nasceram direto em modo de bloqueio depois de conferir que nenhum pod vivo as violava; um pod que já roda não é reavaliado, então uma violação só aparece quando o controller tenta criar o próximo.

A aplicação delas está na primeira onda de sincronização, junto dos operadores, e não depois dos workloads. O root só avança para a onda seguinte quando a anterior está saudável, então uma política que só fosse aplicada depois de um workload que depende dela travaria tudo, o workload recusado pela política antiga e a política nova esperando o workload ficar saudável. Foi exatamente o que aconteceu ao ligar o Grafana, e essa primeira onda é o que impede a repetição.

### Benchmark CIS

O benchmark CIS do node roda toda semana, com a imagem oficial do kube-bench pinada por digest, restrito às checagens de política (RBAC, identidade de workload, Pod Security e políticas de rede).

As seções de master e node ficam de fora de propósito: no k3s, o API server e o kubelet rodam dentro do mesmo processo, e o perfil lê os argumentos deles por um mecanismo que não existe na imagem, então dentro de um pod essas checagens reportam falhas que não são reais.

Com esse recorte o Job não precisa de acesso ao processo nem de montagem do host: roda sem root, com sistema de arquivos raiz somente leitura, num namespace próprio com Pod Security restrito, e com um papel só de leitura sobre pods, identidades de workload, namespaces, RBAC e política de rede, sem acesso a segredo nenhum. O resultado fica no log do Job até seu prazo de vida expirar; uma receita própria roda o benchmark fora do agendamento.

## A política de sincronização padrão

Toda aplicação deste repositório, o root incluído, carrega o mesmo bloco de política de sincronização, e o modelo em [adicionar um satélite novo](../operacional/adicionar-um-satelite.md) já vem com ele. Cada opção resolve um problema concreto do Argo em operação automática. O bloco ser idêntico em toda parte é o que dá valor a ele: uma aplicação que precise de algo diferente passa a ser uma exceção visível no diff, em vez de mais uma variação entre muitas.

Os dois parágrafos abaixo percorrem as opções pelo problema que cada uma evita, que é a forma de decidir se uma exceção futura se justifica.

A aplicação por server-side apply, o mesmo modo que as roles Ansible usam nos charts, evita o limite de tamanho de anotação em definições de tipo grandes e deixa o Argo dono só dos campos que ele declara. Falhar em recurso compartilhado impede a sincronização se mais de uma aplicação tentar gerenciar o mesmo recurso, em vez de deixá-las brigar indefinidamente por ele.

Adiar a remoção posterga a remoção de recursos que saíram do git para depois que tudo o mais da sincronização está saudável, então uma migração que cria o novo antes de apagar o velho não fica sem o velho no meio do caminho. Remover em primeiro plano faz a remoção esperar os dependentes sumirem, uma implantação só é dada como removida depois dos seus pods, o que torna o resultado de uma sincronização observável de verdade.

O bloco de repetição com espera crescente e um teto de tentativas cobre o caso comum de uma sincronização falhar só porque um webhook de admissão ou uma definição de tipo ainda estava subindo; sem ele, a aplicação fica em erro até alguém clicar em sync. Recusar diretório vazio impede que um diretório vazio por engano apague tudo o que a aplicação gerencia.

O limite de histórico de revisão mantém só as últimas revisões para rollback, o suficiente para desfazer uma sincronização ruim sem acumular histórico no estado do Argo.

## Gate de deriva zero

Nenhuma aplicação nova entra com sincronização automática ligada de primeira. A regra é que ela nasce com sincronização manual, o operador roda o comparador de diferenças do Argo até o resultado ser vazio, e só então a sincronização automática entra no manifesto.

A razão é a remoção automática: uma aplicação automática com essa opção apaga do cluster tudo o que não está no git, e um diff não vazio na primeira sincronização significa que algo vivo no cluster não está no git, ou seja, seria apagado.

A ordem de liberação segue o risco: primeiro as aplicações que só criam recursos novos, depois as que adotam recursos existentes, por último as que gerenciam dados, que só saem do manual depois da proteção contra remoção no próprio recurso, como o guia de satélite descreve.

As aplicações que existiam quando essa regra entrou, incluindo o Argo CD Image Updater que o Kargo depois substituiu, já passaram por esse gate e saíram do outro lado com sincronização automática ligada; nenhuma ficou presa em manual.

Adotar um recurso já vivo tem uma armadilha própria, o nome do release do Helm. O cert-manager foi o primeiro caso real: o wrapper local precisou declarar o mesmo nome de release que a instalação anterior por Ansible usava, senão o Argo cria objetos paralelos em vez de reconhecer os existentes, porque o nome do release entra no nome de vários recursos do chart.

A consolidação do blog trouxe uma variante do mesmo problema: quando uma aplicação antiga já é gerenciada pelo próprio Argo, ela herda o nome do release do nome dela mesma, sem precisar declarar o nome explicitamente, então a aplicação nova só adota de forma limpa se receber exatamente o mesmo nome da antiga.

O nome do release não é o único critério, e o caso do Postgres do blog mostrou o outro. Quando a categorização em operadores, plataforma e dado chegou e o banco do blog foi promovido de pasta, o nome da aplicação mudou junto, para não colidir com uma futura aplicação de dado de outro satélite.

Fixar o nome antigo de release não resolveu, porque quem decide se uma aplicação pode assumir um recurso já existente é uma anotação de rastreio que o Argo grava em cada um, com o nome da aplicação como prefixo.

Com a falha em recurso compartilhado ativa, a aplicação nova se recusou a assumir recursos marcados com o nome antigo, e cada sincronização falhou até a anotação ser reescrita à mão, seguida de uma sincronização manual, já que o Argo não tenta de novo sozinho uma revisão que falhou. Renomear uma aplicação que já gerencia recursos exige esse mesmo passo; a alternativa é manter o nome antigo.

Onde o Kargo grava a tag de imagem resolvida como parâmetro direto na aplicação, em vez de um commit, a aplicação nova precisa declarar esse mesmo parâmetro com o valor atual logo na criação.

Esse parâmetro vive em mais de um dono ao mesmo tempo, o git e o Kargo, então o root declara uma exceção de diferença ignorada para esse parâmetro específico da aplicação do blog: sem isso, a autocorreção do root devolvia a tag do git a cada reconciliação e desfazia toda promoção de imagem, o que só apareceu quando uma imagem nova do blog ficou presa na tag antiga.

O valor declarado no manifesto continua sendo o ponto de partida de uma instalação do zero, e vale atualizá-lo quando convém, mas não é mais o que decide a imagem em execução; ele fica para trás assim que o Kargo promove uma imagem nova.

O caminho inverso também é declarado. Toda aplicação carrega um finalizer do Argo, então apagar o arquivo dela do git faz o root removê-la e o Argo remover, em cascata, tudo o que ela criou. Antes do finalizer, o root removia só o objeto da aplicação e os recursos ficavam órfãos no cluster, ainda com a anotação de rastreio de quem os criou; foi assim com o Image Updater quando o Kargo o substituiu, e a limpeza foi à mão.

O preço da cascata é que ela não distingue uma implantação de um banco, por isso o que guarda estado leva a proteção contra remoção no próprio recurso: os bancos do CNPG do blog e do Keycloak, a classe de armazenamento padrão e o volume do Portainer. Uma opção cobre o recurso sumir do git com a aplicação viva; a outra cobre a aplicação inteira sumir.

Os namespaces de plataforma já tinham essa segunda proteção pela mesma razão, e o root fica de fora do finalizer de propósito: ele é aplicado pelo Ansible, não por outra aplicação, e uma cascata a partir dele apagaria o cluster inteiro.

O sops-secrets-operator é o único caso que pulou o diff explícito. A role de bootstrap da chave age rodava depois dele no playbook, então a aplicação nunca chegou a sincronizar de verdade, ficou com o namespace `sops` vazio.

Sem nenhum recurso vivo fora do git para comparar, não existe diff possível de rodar; a sincronização automática entrou direto, e a correção da ordem das roles é o que garante que o segredo que ele monta já existe na primeira sincronização de verdade.

O banco do CNPG do blog apresentou, por um tempo, uma pista falsa: o diff cru do Kubernetes mostrava muitos campos default que o webhook do operador CloudNativePG preenche no objeto vivo e que o manifesto deste repositório nunca declara.

A investigação real, usando o próprio motor de comparação do Argo, mais confiável porque já normaliza esse tipo de campo preenchido pelo webhook, mostrou zero diferença de conteúdo, mesmo com o recurso listado como fora de sincronia no resumo da aplicação. Sincronizações reais confirmaram isso na prática: nenhuma tocou em nada, o banco continuou saudável e sem reiniciar.

Não existe campo concreto para declarar numa exceção de diferença ignorada, porque não existe diferença de conteúdo a ignorar; esse rótulo, especificamente para este banco, é uma inconsistência de cache do próprio Argo para esse tipo de recurso, não um sinal de deriva de configuração. Confirmado como seguro, a sincronização automática foi ligada mesmo assim.

## Por que projetos separados, e não um só

A alternativa mais simples seria um único `AppProject` com permissão ampla para tudo. O problema é que isso apagaria justamente a garantia que se quer: que um repositório de aplicação (potencialmente escrito e mantido com menos rigor de revisão do que este repositório de infraestrutura) não consiga, por acidente ou não, tocar em nada além do próprio namespace.

Separar os projetos torna essa garantia parte da configuração do próprio ArgoCD, não uma convenção que depende de disciplina humana para se manter.

## Continue por aqui

[Adicionar um satélite novo](../operacional/adicionar-um-satelite.md) aplica essa separação na prática, com o `just` que escreve a `Application`.
