# Arquitetura GitOps do projeto

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

O site do blog agora é estático e publicado pelo GitHub Pages. No cluster, a pasta `satellites/blog` mantém somente recursos compartilhados do namespace e o túnel Cloudflare; não há aplicação web do blog.

## Serviços compartilhados e site estático

O site `blog.guesant.net` é gerado com Hugo e publicado no GitHub Pages. O cluster mantém o Cloudflared no namespace `blog` porque o mesmo túnel atende `ops.guesant.net`, `auth.guesant.net` e `atlas.guesant.net`; ele não serve o site.

O PostgreSQL compartilhado mantém somente os bancos e roles de Keycloak e Atlas. O banco, as roles e as credenciais `portfolio` foram removidos. O Silo continua atendendo Atlas; o bucket, a policy, o usuário e as credenciais `portfolio` também foram removidos.

O Argo CD continua sendo a fonte de estado desejado. Os dados retirados tinham políticas de retenção e proteções contra prune, então foram apagados explicitamente depois da remoção de suas declarações GitOps.

O namespace `blog` não tem aplicação web. Seu único workload é o Cloudflared, que mantém o túnel compartilhado e não monta token da API do Kubernetes.

O sops-secrets-operator segue o mesmo padrão de endurecimento, com o `securityContext` do chart ligado: seccomp `RuntimeDefault`, sem root, sem escalada e sem capabilities.

Ele é a única peça desta lista que precisa de um token de `ServiceAccount`, porque o trabalho dele é justamente escrever segredos no cluster a partir do que está cifrado no git. Endurecer o resto do pod importa mais nesse caso, e não menos, já que um processo com esse acesso é o alvo mais atraente do namespace.

Todo namespace criado por uma aplicação recebe os labels de Pod Security `restricted` nos três modos (`enforce/warn/audit`).

Nos operadores, isso vem do `managedNamespaceMetadata` do `syncPolicy` da própria aplicação.

O `Namespace/blog`, com os mesmos labels, é declarado à parte em `argocd/apps/platform/namespaces`.

Essa aplicação, do projeto de infraestrutura, leva `prune` desligado e `Delete=false`, para que nenhuma remoção em cascata vinda do satélite apague o namespace com tudo dentro.

O `kube-system` fica de fora, porque o Cilium e os componentes do k3s precisam de privilégio.

O job `pod-security` da CI falha se um namespace novo nascer sem o label de `enforce`.

Cada peça que precisa de segredo referencia um `SopsSecret` no diretório centralizado correspondente ao destino. Esses manifests são sincronizados diretamente pelo Argo CD, sem um chart intermediário.

Nenhuma delas usa mais `SealedSecret`, o mecanismo antigo, removido junto com o controller que o cifrava.

| Arquivo do `SopsSecret` | O que guarda | Como chega ao processo |
| --- | --- | --- |
| `cloudflared/templates/tunnel-token.sops-secret.yaml` | Token do túnel Cloudflare | Variável de ambiente do processo Cloudflared |

As regras de ingress do túnel ficam na Cloudflare, declaradas em [OpenTofu: a camada da Cloudflare](opentofu.md).

### Políticas de rede

O Cilium roda com `policyEnforcementMode: always`, em que todo pod nega por padrão qualquer tráfego que nenhuma política libere, com ou sem política própria.

Por isso cada namespace tem uma `CiliumNetworkPolicy` que lista o que ele de fato usa, levantado nos veredictos `AUDIT` do Hubble.

`argocd/apps/platform/network-policies`, no projeto de infraestrutura, cobre os namespaces `argocd/cert-manager/cnpg-system/sops/kube-system`.

Ela libera DNS para o CoreDNS, API server, entrada vinda do host e do API server para sondas, métricas e webhooks, saída 443 do Argo CD para o GitHub e os registros, e o CNPG falando com o banco compartilhado.

O namespace `blog` mantém somente o cloudflared, que usa as liberações necessárias para DNS, o `argocd-server`, o Keycloak e a borda da Cloudflare.

O cloudflared alcança o Keycloak porque `auth.guesant.net` entra pelo mesmo túnel do blog e é roteado direto para o servidor, sem passar pelo app.

A regra correspondente já existia, mas com um seletor de rótulo que não batia com o pod real (`app: keycloak` em vez de `app.kubernetes.io/name: keycloak`), então essa saída ficava bloqueada até o rótulo ser corrigido.

Desde que `policyAuditMode` virou `false` (ver [checklist de segurança](checklist-de-seguranca.md)), essas regras bloqueiam de verdade o que não liberam, não só registram.

O namespace `blog` é o único do cluster com mais de um mecanismo de política de rede ao mesmo tempo, e não por uma migração pela metade.

O ingress do namespace `blog` é limitado pela regra `default-deny-ingress`; o túnel Cloudflare é o único workload nesse namespace.

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
| `data/` | `1` | Dados com estado, dedicados ou compartilhados, mantidos fora das aplicações que os consomem; hoje `shared-postgres`, `silo` e `redis`, no projeto `infra` |
| `satellites/<nome>/` | `0` a `4` | As `Application` de um satélite consolidado neste repositório, no projeto `satellites`; `satellites/blog/` contém apenas políticas de rede, o segredo do túnel e o Cloudflared |
| `satellites/launcher/` | `0` | Chart que cria as `Application` dos satélites externos atualmente declarados |

Todas essas pastas vêm de um mini chart wrapper em [argocd/apps](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps), organizado nas mesmas categorias, não de um chart upstream apontado direto, para manter `sourceRepos` do projeto `infra` restrito a este único repositório.

Os values desses wrappers declaram `requests` e limite de memória de cada operador, medidos contra o consumo real, e pinam as imagens por digest.

O cert-manager usa o campo `image.digest` do próprio chart, e CNPG, sops-secrets-operator e Kargo usam o formato `tag@sha256:...`, que o Renovate atualiza junto da tag.

Apontar direto para um chart upstream funcionaria, mas obrigaria a incluir o repositório dele em `sourceRepos`, e a partir daí qualquer aplicação do projeto `infra` poderia sincronizar de lá. Manter a lista com um endereço só transforma "de onde este cluster aceita manifesto" numa resposta de uma linha, verificável sem ler cada aplicação.

O namespace `blog` mantém um `LimitRange` e uma quota para limitar recursos dos workloads. Como o túnel Cloudflare é o único workload restante, esses limites agora se aplicam a ele.

A divisão entre `operators/platform` existe porque cada um falha de forma diferente: um operator que sai do ar deixa objetos que ele já criou (um `Certificate/Cluster`) sem reconciliação, enquanto uma ferramenta de plataforma que sai do ar só perde a própria função.

`data/` fica fora da pasta do satélite mesmo quando o dado é exclusivo dele, porque o teto de permissão de dado, com retenção de PVC e `Prune=false` no recurso, é sempre mais conservador que o do resto do satélite.

Misturá-los nivela o mais restritivo pelo menos restritivo por engano.

As três pastas respondem, no fim, a uma pergunta só: o que sobra se esta peça sumir do git amanhã. Some um operator e ficam objetos sem quem os reconcilie; some uma ferramenta de plataforma e some só ela; some um banco e some o dado, que é o único caso irreversível.

## Satélites e entrega de imagens

O chart `satellites-launcher` cria as aplicações dos satélites declarados em sua lista. O Kargo permanece instalado, mas a aplicação de entrega foi removida porque nenhum satélite usa atualmente Warehouse, Stage ou promoção de imagens. O site Hugo é publicado pelo GitHub Pages, fora do cluster.

Para cadastrar outro satélite ou reativar entregas pelo Kargo, consulte [adicionar um satélite novo](../operacional/adicionar-um-satelite.md) e [Rollout de imagens](rollout-de-imagens.md).

## Os componentes de plataforma

Os parágrafos abaixo descrevem, um a um, os componentes de `platform/` que não têm página própria na arquitetura. O [ingress](ingress.md), o [rollout de imagens](rollout-de-imagens.md) com o Kargo e a camada da [Cloudflare](opentofu.md) têm as suas.

O que aparece aqui, portanto, não é a lista completa da camada de plataforma, e sim o que não coube em outro lugar. Cada bloco segue a mesma ordem: onde o componente mora, o que ele resolve e qual decisão dele custou mais caro para chegar ao formato atual.

### Identidade: Keycloak

A identidade vive no Keycloak, em peças com responsabilidades separadas.

O servidor é um `StatefulSet` escrito à mão em `argocd/apps/platform/keycloak`, no mesmo molde do Portainer.

Ele leva a imagem oficial 26.7.4 por digest, um pod só, `securityContext` endurecido e sem token de `ServiceAccount`, porque o processo não fala com o Kubernetes.

Ele roda `kc.sh start` sem `--optimized`, então refaz a configuração a cada início, alguns segundos a mais que não pesam num único pod.

O cache interno fica em modo `local`, porque não há segundo pod com quem formar cluster.

A conexão vem dos Secrets de aplicação replicados pelo `ClusterSecretStore/data-secrets`. Atlas e Keycloak têm slots de login A/B independentes; a role proprietária de cada banco não aceita login.

O cluster compartilhado fica em `argocd/apps/data/shared-postgres` e declara `instances: 1`. O failover do operador não se aplica aqui: não há réplica para promover quando a primária cai. A proteção que sobra é o reinício automático do pod pelo Kubernetes sobre o mesmo volume, que sobrevive pela retenção do provisionador, não por existir uma segunda cópia do dado. Um segundo nó mudaria esse cálculo: com um nó só, mais instâncias protegeriam o processo, não o host onde o volume mora.

| Banco | Roles de aplicação | Secrets de origem | Namespace consumidor |
| --- | --- | --- | --- |
| `atlas` | `atlas_a`, `atlas_b` | `atlas-postgres-app-a`, `atlas-postgres-app-b` | `atlas` |
| `keycloak` | `keycloak_a`, `keycloak_b` | `keycloak-postgres-app-a`, `keycloak-postgres-app-b` | `keycloak` |

Os recursos `Database` e `DatabaseRole` do chart declaram esses bancos, suas roles proprietárias e os slots de aplicação sem reutilizar a credencial de superusuário. As políticas de retenção protegem os bancos e as roles contra remoção acidental pelo GitOps.

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

O client secret e o segredo do cookie ficam nos `SopsSecret` centralizados, com a anotação do Reloader para reiniciar quando eles mudarem.

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

[Adicionar um satélite novo](../operacional/adicionar-um-satelite.md) descreve o cadastro de um satélite e a criação da `Application` correspondente.

<!-- reviewed: argocd -->
