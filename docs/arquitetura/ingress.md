# Ingress: os nomes internos pela tailnet

<!-- source-of-trust paths="argocd/apps/platform/ingress argocd/applications/platform/ingress.yaml" -->

O DNS interno da [tailnet](tailscale.md) faz todo nome sob o domínio interno apontar para o node, mas um endereço só não diz qual serviço atender. Quem separa um nome do outro e entrega cada um ao serviço certo é a camada descrita aqui: um Traefik declarado como aplicação do Argo CD em [argocd/apps/platform/ingress](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps/platform/ingress), implementando a [Gateway API](../aprender/gateway-api.md), com certificados emitidos por uma autoridade certificadora interna do [cert-manager](../aprender/tls-automatico.md).

As três decisões que essa camada carrega estão explicadas nas seções seguintes: por que o Traefik escuta direto no node em vez de atrás de um Service, por que as rotas são Gateway API e não o recurso próprio do Traefik, e por que os certificados vêm de uma CA do próprio cluster. Nenhuma delas é o caminho mais comum num cluster Kubernetes, e cada uma existe por uma limitação concreta deste node.

## Por que o Traefik escuta direto no node

A role do k3s desliga o Traefik e o ServiceLB que o k3s traria embutidos, e o [modelo de ameaças](modelo-de-ameacas.md) explica o motivo: um serviço do tipo [LoadBalancer ou NodePort](../aprender/firewalld.md) chega ao node por um DNAT que muda o destino do pacote antes de o firewalld avaliá-lo, então o tráfego passa pela chain `FORWARD` e nenhuma regra de zona sobre aquela porta é consultada.

Expor um serviço assim tornaria o firewall uma proteção falsa para ele. O problema não é de configuração: não existe regra de zona que alcance um pacote que já foi reescrito e desviado para essa chain, então ajustar o firewalld não resolveria. A saída é não depender do mecanismo que causa o desvio, e é isso que a seção descreve.

O Traefik daqui não usa Service para receber tráfego. Ele roda em modo de rede do host, escutando nas portas 80 e 443 do próprio node, como o processo do k3s escuta na 6443. Um pacote para essas portas é tráfego destinado ao host, passa pela chain `INPUT`, e o firewalld decide por zona: a role de firewall libera HTTP e HTTPS só na zona da tailnet, ligada à interface da tailnet, enquanto a zona pública continua só com SSH.

Da rede local ou da Internet, as portas 80 e 443 do node seguem fechadas; da tailnet, abertas. É a mesma lógica que já restringia a API do k3s por CIDR, só que aqui a fronteira é a interface.

Isso tem custos, todos declarados. O namespace do ingress precisa do nível privileged do Pod Security Admission, porque o nível baseline proíbe modo de rede do host; é o mesmo caso do namespace de monitoring, por causa do node-exporter, e o gate `check-namespace-pod-security.sh` exige que o nível esteja escrito na aplicação.

Um processo sem privilégio não consegue escutar em porta abaixo de 1024 no namespace de rede do host: como as políticas de admissão exigem que todo contêiner rode como não-root e derrube toda capability, a role de hardening de sysctl baixa `net.ipv4.ip_unprivileged_port_start` para 80 no node.

Esse sysctl é por namespace de rede, e os pods comuns já recebem o valor zero do kubelet dentro do seu próprio namespace, então a mudança só alcança o que roda no namespace do host: o Traefik e, em teoria, qualquer outro processo sem privilégio do node, que hoje não existe.

## Por que Gateway API, e por que não o Cilium

O Traefik implementa a [Gateway API](../aprender/gateway-api.md) do Kubernetes, não o seu próprio IngressRoute nem o Ingress clássico: o provider `kubernetesIngress` fica desligado nos values, e nenhum IngressRoute é declarado no repositório. As rotas viram HTTPRoute, um recurso padrão que qualquer outra implementação entende, então trocar o Traefik por outro controlador no futuro é trocar o GatewayClass, não reescrever as rotas.

Os CRDs da Gateway API vêm pelo chart `traefik-crds` do próprio projeto, na mesma versão que o Traefik testou, em vez de um manifesto baixado do GitHub, para que o Renovate os acompanhe como qualquer outra dependência do Chart.yaml.

O Cilium também implementa a Gateway API, e seria uma peça a menos. Ele não foi escolhido por uma razão concreta deste node: o agente está ligado só às interfaces físicas (`devices: eth+ wlan+` nos values do Cilium), e todo o balanceamento dele acontece em BPF anexado a essa interface. Tráfego chegando pela interface da tailnet não passa por nenhum desses hooks, então um Gateway do Cilium nunca veria uma conexão vinda da tailnet.

Incluir a interface da tailnet na lista acoplaria o agente a uma interface que só existe depois de o tailscaled subir e que é recriada quando ele reinicia; e o Envoy do Cilium está desligado (`l7Proxy: false`) justamente para poupar memória no Raspberry Pi. O Traefik custa menos memória do que ligar o Envoy custaria, e não depende de qual interface o Cilium controla.

## O que o chart declara

O Gateway se chama `internal` e tem dois listeners, listados na tabela abaixo. Tanto o Gateway quanto as rotas declaram por extenso os campos que a Gateway API preencheria por padrão, porque o Argo CD compara o manifesto do git com o objeto vivo já preenchido e trataria cada default como deriva.

| Listener | Porta | Faz o quê |
| --- | --- | --- |
| `web` | 80 | só redireciona para HTTPS de forma permanente |
| `websecure` | 443 | termina TLS com o certificado `internal-domain-tls` e aceita rotas de qualquer namespace |

As rotas atuais vivem em [routes.yaml](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/platform/ingress/templates/routes.yaml). O que não tem rota é o que não tem interface HTTP para uma pessoa: os operadores, os bancos do CNPG, os exporters e o blog, que já é público pelo túnel. A regra que decide se algo entra na tabela abaixo é essa, e não a importância do componente: um operador sem console não ganha nome interno só por ser central.

A tabela lista o nome, o serviço de destino e como o login é resolvido em cada caso, porque essa última coluna é a que mais varia.

| Nome interno | Serviço | Login |
| --- | --- | --- |
| `argocd.guesant.internal` | `argocd-server`, porta 80 | OIDC próprio com o Keycloak |
| `keycloak.guesant.internal` | `keycloak-service`, o console de administração | O próprio Keycloak |
| `portainer.guesant.internal` | Portainer | OIDC próprio com o Keycloak |
| `kargo.guesant.internal` | `kargo-api`, porta 80 | OIDC próprio com o Keycloak |
| `hubble.guesant.internal` | Hubble UI do Cilium | `Middleware` `keycloak-login`, copiado para `kube-system` |
| `dashy.guesant.internal` e o apex `guesant.internal` | Dashy, a página inicial com o link de cada um dos outros | `Middleware` `keycloak-login` |

Prometheus, Alertmanager, Hubble UI e Dashy não têm autenticação própria, então o Traefik pede o login por eles quando a rota está habilitada. Hubble UI e Dashy carregam um filtro para o middleware `keycloak-login`, declarado em [middlewares.yaml](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/platform/ingress/templates/middlewares.yaml) uma vez por namespace, porque a Gateway API só aceita referência a um middleware do mesmo namespace da rota. As rotas e o middleware do namespace `monitoring` só são renderizados quando a stack de monitoramento está habilitada.

Ele é um forwardAuth que encaminha cada requisição à raiz do oauth2-proxy: com uma sessão válida a resposta é 202 (o upstream dele é `static://202`) e o Traefik deixa passar, repassando o usuário e o e-mail em cabeçalhos; sem sessão a resposta é o 302 para o Keycloak, que o Traefik devolve ao navegador tal como veio.

O oauth2-proxy reconstrói a URL original a partir dos cabeçalhos `X-Forwarded-*` para voltar a ela depois do login.

Uma primeira versão consultava `/oauth2/auth` e tentava converter o 401 num redirecionamento com o middleware de erros, mas esse middleware preserva o status original, e um 401 com cabeçalho de localização não leva um navegador a lugar nenhum.

O oauth2-proxy vive em `argocd/apps/platform/oauth2-proxy`, atende em `auth.guesant.internal` só no caminho de callback, usa o client público do realm management com PKCE, exige o grupo de administradores no claim de grupos, e grava um cookie para o domínio interno inteiro, então um login vale para todos os nomes cobertos.

Alguns detalhes fazem o forward auth funcionar em modo de rede do host: `dnsPolicy: ClusterFirstWithHostNet`, sem o qual o pod usaria o DNS do host e não resolveria o Service do oauth2-proxy, e o provider `kubernetesCRD` ligado, porque Middleware é um recurso do Traefik, não da Gateway API.

Esse provider é a única concessão ao mundo fora da Gateway API nesta camada, e ela existe porque a especificação ainda não tem um equivalente padrão para autenticação na borda. Ligar esse provider também habilitaria o IngressRoute, que é servido por ele, mas nenhum existe no repositório: o `kubernetesIngress` está desligado nos values, e o que o `kubernetesCRD` de fato carrega aqui são os middlewares.

Os serviços que falam OIDC por conta própria precisaram de ajustes para viver atrás de um TLS terminado fora deles. Os values da role do ArgoCD ligam `server.insecure`, que faz o servidor do Argo servir HTTP puro em vez de redirecionar para o seu próprio certificado autoassinado; o webhook do GitHub, que o cloudflared já entregava na porta 80, continua igual.

O CR do Keycloak declara `hostname.admin` como o nome interno, então o console de administração deixa de responder em localhost por encaminhamento de porta e só existe pela tailnet.

O Deployment do Traefik usa a estratégia Recreate, porque em modo de rede do host um pod novo não consegue abrir as portas 80 e 443 enquanto o antigo ainda as ocupa: numa atualização gradual ele ficaria pendente para sempre, e o preço da estratégia é uma interrupção de alguns segundos a cada mudança de configuração.

A aplicação de ingress, como as demais, carrega o [finalizer de recursos do Argo](gitops-root-e-satelites.md), então removê-la do git derruba o Gateway, as rotas e a CA interna de uma vez; nada aqui guarda estado que precise da opção de proteção contra remoção, e o certificado da CA se regenera pelo cert-manager.

Regenerar não é gratuito, porém: a CA nova tem chave nova, e cada dispositivo que confiava na anterior precisa instalar o certificado outra vez. É um custo aceitável para uma camada que não guarda dado de ninguém, e o mesmo passo já existe documentado em [rotacionar credenciais](../operacional/rotacionar-credenciais.md).

Os certificados vêm de uma cadeia curta do cert-manager, declarada em [internal-ca.yaml](https://github.com/guesant/hl-infrastructure/blob/main/argocd/apps/platform/ingress/templates/internal-ca.yaml): um [emissor autoassinado](../aprender/tls-automatico.md) emite um certificado de CA, guardado no segredo `internal-ca` do namespace `cert-manager`, e um segundo emissor usa essa CA para emitir o certificado curinga do domínio interno, que o Gateway consome.

O Tailscale só emite certificado para nomes `*.ts.net`, e o Let's Encrypt não emite para um domínio que não existe na Internet, então a CA interna é o único caminho para HTTPS nesses nomes. O certificado do domínio tem validade curta e roda a cada renovação; a CA tem validade longa e mantém a mesma chave ao renovar, para que os dispositivos que a confiaram uma vez não precisem repetir o passo.

A chave privada da CA é o único segredo desta camada e nunca sai do cluster; o que sai é o certificado público, que `just internal-ca` imprime para você instalar nos seus dispositivos, como o [primeiro bootstrap](../operacional/primeiro-bootstrap.md) descreve.

O Traefik em si roda com a imagem por digest do GHCR, sem dashboard, sem verificação de versão nova nem telemetria, com access log ligado para o journal do node. O Service do chart fica desligado, porque em modo de rede do host ele não teria função; só o Service de métricas existe. Como a stack de monitoramento está desligada por padrão, o `ServiceMonitor` também permanece desabilitado para não criar uma referência a um coletor ausente. Ao reativar o monitoramento, as rotas de Grafana, Prometheus e Alertmanager, o middleware do namespace `monitoring` e a coleta do Traefik precisam ser habilitados de forma coerente.

As portas internas do processo, a de saúde e a de métricas, foram movidas para valores que não colidem com o node-exporter, que também escuta no namespace de rede do host.

## Como uma requisição chega ao serviço

Um dispositivo da tailnet abre `https://argocd.guesant.internal`. O split DNS devolve o endereço do node na tailnet, e a conexão para a porta 443 chega pela interface da tailnet; o firewalld a aceita porque a zona da tailnet libera HTTPS. O Traefik, escutando no host, termina o TLS com o certificado curinga, encontra a rota cujo hostname bate e encaminha para o servidor do Argo pela rede de pods.

Como o Traefik está no namespace de rede do host, o Cilium o vê com a identidade `host`, e as políticas de rede dos namespaces do ArgoCD e do Keycloak já admitem ingresso dessa identidade; nenhuma política nova foi necessária. Da rede local, sem a tailnet, a mesma requisição encontra a porta 443 fechada na zona pública.

## Continue por aqui

Para o DNS que faz esses nomes resolverem, veja [Tailscale: acesso remoto e DNS interno](tailscale.md). Para o raciocínio sobre `INPUT` e `FORWARD` que decide como um serviço pode ser exposto neste node, veja o [modelo de ameaças](modelo-de-ameacas.md). Para rotacionar a CA interna, veja [rotacionar credenciais](../operacional/rotacionar-credenciais.md).
