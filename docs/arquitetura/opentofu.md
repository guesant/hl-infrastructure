# OpenTofu: a camada da Cloudflare

<!-- source-of-trust paths="tofu/*/*.tf tofu/*/terraform.tfvars .tools/tofu-run.sh .tools/tofu-state-passphrase.sh .tools/cloudflare-tunnel-token.sh .tools/check-placeholders.sh .tools/tofu-validate.sh" -->

O Ansible prepara o node e o Argo CD cuida de tudo que roda dentro do cluster, mas o caminho de um visitante até o blog começa fora desses sistemas: no DNS da Cloudflare e no túnel que liga a borda da Cloudflare ao cloudflared dentro do cluster.

[tofu/cloudflare](https://github.com/guesant/hl-infrastructure/tree/main/tofu/cloudflare) declara essa parte com OpenTofu, e o resto desta página explica o que ele possui, o que ele deliberadamente não possui e por quê.

O título da página ficou estreito com o tempo: a mesma mecânica passou a declarar o split DNS da tailnet e os realms do Keycloak, cada um no seu módulo, e as seções finais tratam desses dois.

O que reúne os três casos não é o provider, e sim a situação: estado que vive na conta de um serviço de terceiro, sem nada dentro do cluster para reconciliá-lo.

## O que o OpenTofu declara

O módulo declara o túnel `blog` (`cloudflare_zero_trust_tunnel_cloudflared`).

Ele também declara a configuração de ingress desse túnel (`cloudflare_zero_trust_tunnel_cloudflared_config`).

O provider da Cloudflare está fixado na versão `5.25.0`, com os hashes correspondentes registrados no lockfile do módulo. Atualizar essa versão altera a seleção do provider e exige revisar a validação do módulo antes de qualquer apply.

O módulo também declara os registros CNAME apontando para `<id do túnel>.cfargotunnel.com`.

Esses registros são os do blog, no domínio raiz `guesant.net/www.guesant.net`, que servem o mesmo conteúdo sem redirect.

Também é registro o de operação, `ops.guesant.net`.

O CNAME no apex funciona porque a Cloudflare o achata num endereço na hora de responder o DNS, sem precisar de registro A.

Os registros do apex e do www têm `lifecycle { prevent_destroy = true }`: um `plan` que os destruiria, seja por um recurso removido do código, seja por uma mudança que obrigue recriar, falha antes do apply, porque apagar esses registros tira o blog do ar.

Os CNAME de `guesant.net` e www já existiam antes do OpenTofu, apontando para o site antigo na Vercel.

Em vez de apagá-los e recriá-los, eles foram trazidos para o state com `tofu import` (o ID de import é `<zone_id>/<id do registro>`), e a virada para o túnel foi um apply que só trocou o destino.

A ordem evitou queda: primeiro o túnel, o ingress e o registro de operação, aplicados com `-target`; depois o token do túnel no cluster e o cloudflared conectado.

Só então veio a troca do destino do apex e do www, sempre a partir de um plano salvo (`-out`, arquivo `.tfplan` ignorado pelo git e cifrado como o state) e conferido antes do apply.

O túnel é remotamente gerenciado (`config_src = "cloudflare"`): as regras de ingress moram na própria Cloudflare, e o cloudflared no cluster não carrega arquivo de configuração nenhum, só o token que o identifica.

O webhook do GitHub chega por `ops.guesant.net`.

A regra casa só o caminho exato `^/api/webhook$` antes de mandar para o `argocd-server`.

O destino é `https://argocd-server.argocd.svc.cluster.local:443`, e não a porta 80, por um motivo que não aparece em nenhum lint.

Sem o modo `server.insecure`, o argocd-server responde a qualquer requisição HTTP com um redirect 307 para HTTPS, e o GitHub não segue redirect em webhook, então toda entrega falharia.

O certificado do `argocd-server` é autoassinado, por isso a regra liga `no_tls_verify`, só nela e num trecho que não sai do cluster.

O túnel não reescreve caminho: ele escolhe esquema, host e porta do destino, mas encaminha o caminho do jeito que chegou.

O hostname da API encaminha tanto `/api/v1` quanto `/docs` para o serviço Laravel. Assim, a API pública e a documentação OpenAPI permanecem no mesmo origin sem expor a interface administrativa.

Qualquer outro caminho nesse hostname cai no 404, então a interface e a API do Argo CD nunca ficam expostas; apontar o hostname inteiro para o `argocd-server` publicaria interface e API na internet.

`guesant.net/www.guesant.net` vão inteiros para o `Service` do blog, e qualquer outro hostname recebe 404.

Separar os hostnames tira o tráfego de operação do site público: nenhuma rota do blog colide com o webhook, e regras da Cloudflare, como WAF ou Access, podem valer só para o de operação. Uma validação do módulo recusa usar o mesmo hostname para blog e operação.

`auth_hostname` (`auth.guesant.net`) leva ao Keycloak pelo mesmo túnel.

A regra de ingress casa só os caminhos `^/(realms|resources)/`, que são as páginas de login, os endpoints OIDC e os arquivos estáticos delas.

Qualquer outro caminho nesse hostname, incluindo o console de administração em `/admin`, cai na regra final e recebe 404 na borda da Cloudflare, sem chegar ao cluster.

As validações da variável recusam um hostname igual ao do blog ou ao de `ops_hostname`, para que o provedor de identidade nunca divida hostname com outro tráfego.

`cache.tf` declara um ruleset de cache, na fase `http_request_cache_settings`.

Ele torna tudo sob `/_framework/` elegível a cache na borda respeitando o TTL da origem.

Sem ele a Cloudflare tratava o runtime WebAssembly do blog, um arquivo `.wasm` de alguns megabytes com nome por fingerprint e `Cache-Control: immutable`, como conteúdo dinâmico, e cada visitante novo o baixava do Raspberry Pi pelo túnel.

A extensão `.wasm` não está na lista padrão do que a Cloudflare cacheia, ao contrário de `.js/.css`.

Esses formatos já voltavam como `HIT`.

O ganho é maior do que economia de banda: cada megabyte servido da borda é um megabyte que o Raspberry Pi não empacota nem empurra pelo túnel, e é justamente esse arquivo que todo visitante novo precisa antes de a página funcionar.

A regra é por prefixo de caminho, e não por extensão, para que um runtime com outro formato continue coberto sem mexer aqui.

`waf.tf` declara hoje um ruleset só, de rate limit, dentro dos limites do plano gratuito da zona.

Um segundo ruleset, de regras customizadas na fase `http_request_firewall_custom`, chegou a existir.

Ele bloqueava varreduras por software que esta zona não roda: caminhos terminados em `.php`.

Também bloqueava caminhos começando com `/wp-, /.env, /.git`, ou contendo `phpmyadmin`.

Ele também restringia `ops_hostname` ao POST em `/api/webhook`.

A Cloudflare recusou esse ruleset no plano gratuito da zona, e ele foi removido do código; essa fase de regra customizada exige um plano pago.

A restrição de `ops_hostname` não ficou descoberta por isso, porque a regra de ingress do túnel, descrita acima, já limita esse hostname ao mesmo caminho exato e devolve 404 para qualquer outro.

O que ficou sem cobertura foi só o bloqueio de varreduras por caminho de software que esta zona não roda, e hoje nada barra essas requisições na borda da Cloudflare antes de chegarem ao túnel, onde caem no 404 do hostname correspondente como cairia qualquer caminho inexistente.

O ruleset de rate limit que sobrou bloqueia temporariamente um IP que exceder o limite de requisições declarado em `tofu/cloudflare/waf.tf`.

Isso vale nos fluxos de login do Keycloak (`/realms/homelab/login-actions/, /realms/homelab/broker/`).

A expressão usa só o caminho, sem o hostname, porque no plano gratuito uma regra de rate limit só pode filtrar pelo campo de caminho, e esses caminhos só existem no Keycloak.

Ele não cobre os endpoints de token e de descoberta, porque o Argo CD, o Grafana e o blog os chamam do mesmo IP de saída do node e seriam bloqueados junto.

Esse é o limite real de um rate limit por IP num cluster de um nó só: todo tráfego servidor a servidor sai com o mesmo endereço, e o que seria proteção passa a bloquear o próprio cluster. Restringir a regra aos caminhos que só um navegador de pessoa percorre é o que mantém a proteção onde ela faz diferença, na tentativa repetida de senha.

Esse desenho cria um acoplamento que nenhum gate pega: os destinos do ingress são nomes de `Service` do cluster (`app.blog.svc.cluster.local, argocd-server.argocd.svc.cluster.local`), declarados em outro sistema.

Renomear um desses `Service` num chart do Argo sem mudar `tunnel.tf` quebra o túnel sem nenhum erro de CI; a mudança precisa ir para ambos os lados no mesmo commit.

O acoplamento não tem como ser eliminado, porque o túnel precisa de um destino e o destino vive no cluster; o que dá para fazer é torná-lo visível, e é por isso que ele está escrito aqui. Vale o mesmo cuidado ao renomear um namespace, já que o nome completo do serviço carrega ambos.

O provider avisa, a cada `plan`, que `cloudflare_zero_trust_tunnel_cloudflared_config` não pode ser destruído por ele.

Remover esse recurso do código, ou rodar `tofu destroy`, tira o recurso do state mas deixa a configuração de ingress na API da Cloudflare até alguém apagá-la à mão no dashboard. Para este uso isso não muda nada no dia a dia, mas vale lembrar numa desmontagem do túnel.

É um caso em que o state deixa de descrever a realidade sem que nada acuse: o arquivo diz que o recurso não existe mais, e a API da Cloudflare continua com ele.

Se o túnel for reconstruído depois, a configuração antiga ainda está lá para ser sobrescrita, o que costuma ser inofensivo e é péssimo de descobrir sem aviso.

## O que ele não possui, de propósito

O token que o cloudflared usa para se conectar nunca passa pelo OpenTofu.

O provider da Cloudflare até oferece um data source que lê esse token, mas qualquer valor lido por um data source vai parar no state, e marcar um atributo como `sensitive` só o esconde da saída do terminal, não o tira do arquivo.

Em vez disso, [.tools/cloudflare-tunnel-token.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/cloudflare-tunnel-token.sh) (via `just cloudflare-tunnel-token`) lê do state só o ID do túnel, e pede o token direto à API da Cloudflare.

Ele grava o token recifrado no `SopsSecret` do cloudflared com `sops set --idempotent`, sem arquivo intermediário em texto claro.

A fonte da verdade desse token é a Cloudflare; o `SopsSecret` é uma cópia cifrada para entrega.

O API token que autoriza o OpenTofu a mexer na conta também não é recurso dele.

É um token único, criado à mão no dashboard, com só as permissões estritamente necessárias (Cloudflare Tunnel de edição na conta e DNS de edição na zona do blog).

Um token com permissão de criar outros tokens deixaria o OpenTofu gerenciar credenciais, mas seria praticamente a conta inteira num segredo só, e o valor de cada token criado cairia no state; para um operador só, isso aumenta o risco sem resolver problema nenhum.

## Como as credenciais chegam ao processo

Os segredos ficam separados por nível, porque respondem a perguntas diferentes.

`tofu/state.sops.env` é comum a todo o OpenTofu e guarda só a passphrase do state (`TF_VAR_state_passphrase`).

O OpenTofu entrega essa variável a `var.state_passphrase` pela convenção do prefixo `TF_VAR_`.

Cada módulo guarda as credenciais do próprio provider num arquivo com o nome dele, como `tofu/cloudflare/cloudflare.sops.env`, com o API token da Cloudflare e os IDs da conta e da zona.

Assim um módulo futuro, de outro provider, nunca recebe o token da Cloudflare no ambiente.

Os IDs não são credencial, mas ficam cifrados para este repositório público não apontar para a conta, e as variáveis que os recebem são `sensitive`.

Assim, nem o `plan` nem o `apply` os imprimem.

O hostname do blog continua em texto claro em `terraform.tfvars`: ele é público de qualquer jeito, pelo DNS e pelos logs de certificado TLS, e cifrá-lo só esconderia algo que o próprio site anuncia.

`just tofu <módulo> <argumentos>` chama [.tools/tofu-run.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/tofu-run.sh).

Esse script se reexecuta por dentro de um `sops exec-env` para cada arquivo `.sops.env` envolvido.

Cada `exec-env` decifra os valores só no ambiente do processo filho.

No fim, o script roda `docker run` com a imagem oficial do OpenTofu, passando `-e NOME` para exatamente as variáveis que esses arquivos declaram (os nomes ficam em texto claro num arquivo SOPS de ambiente; só os valores são cifrados).

Passar `-e NOME` sem valor faz o Docker herdar a variável do ambiente, então o segredo não aparece na linha de comando nem toca o disco.

O custo de mais de um arquivo é a Secure Enclave poder pedir biometria mais de uma vez por execução.

A decifragem acontece no host, e não dentro do container, pelo mesmo motivo de `sops-edit` e `sops-sync`: a identidade de rotina do operador vive na Secure Enclave do Mac e não funciona fora dele.

O `plan` não precisa escrever nada na Cloudflare, e um token que só lê diminui o estrago de um `plan` rodado sobre um módulo alterado por engano ou por um provider comprometido.

Por isso o script olha o subcomando: nos comandos de leitura (`plan, show, output, validate, providers, state list, state show`), se o arquivo de segredos declarar `CLOUDFLARE_API_TOKEN_READ`, esse é o valor usado.

É esse valor que o container recebe como `CLOUDFLARE_API_TOKEN`, e o token de escrita nem chega a ser passado.

Nos demais comandos, `apply` e `import` principalmente, vai o token de escrita.

Enquanto o token de leitura não existir, os comandos de leitura avisam e seguem com o de escrita, para que a separação possa ser ligada depois sem quebrar nada; criá-lo no dashboard e gravá-lo com `just sops-edit` é passo manual do operador.

O provider `carlpett/sops`, que decifraria o arquivo de dentro do próprio OpenTofu, ficou de fora.

Configuração de provider não é gravada no state, então `exec-env` já mantém o API token fora dele; nenhum recurso do módulo recebe segredo como argumento, então recursos efêmeros e atributos write-only não teriam onde ajudar; e decifrar dentro do container esbarraria na Secure Enclave de novo.

O provider resolveria um problema que este repositório não tem, porque a decifragem já acontece antes do OpenTofu começar, e traria uma dependência a mais para pinar, atualizar e confiar.

Recusá-lo custa uma linha a mais no script que reexecuta o comando, e é o tipo de troca que vale quando a alternativa é aumentar a superfície do que roda com credencial de escrita.

A regra de `.sops.yaml` para `tofu/**/*.sops.env` é separada da regra dos SopsSecret.

Ela não tem `encrypted_suffix`.

Isso não é detalhe: a regra dos `SopsSecret` só cifra o que está sob `secretTemplates`, e um arquivo de ambiente que caísse nela sairia "cifrado" com todo valor em texto claro.

O gate `security-sopssecrets` confere ambos os tipos de arquivo.

Um módulo pode ainda declarar um `secrets.map`, com variáveis que vêm de outros arquivos SOPS do repositório em vez do seu próprio `.sops.env`.

O mesmo script as extrai com `sops --decrypt --extract` e as entrega da mesma forma. É como os módulos do Keycloak leem os client secrets dos `SopsSecret` que os consumidores montam, sem cópia.

A alternativa seria repetir cada client secret num arquivo do módulo, e duas cópias de um segredo significam duas rotações, das quais uma cedo ou tarde é esquecida. O mapa custa um arquivo de texto com uma linha por variável, legível em revisão, que diz exatamente de onde cada valor vem.

## State cifrado dentro do git

O state fica em `tofu/cloudflare/terraform.tfstate`, commitado, cifrado pela state encryption nativa do OpenTofu.

Um key provider `pbkdf2` deriva a chave da passphrase, e o método é `aes_gcm`.

`enforced = true` vale tanto para state quanto para plan, o que faz o OpenTofu recusar gravar state ou plan em texto claro se a configuração de cifragem sumir.

Commitar evita um serviço novo só para guardar um arquivo pequeno, e o que ele contém é pouco sensível mesmo decifrado (IDs de conta, zona e túnel, e os registros DNS), justamente porque nenhum token passa pelo OpenTofu.

O custo é não ter lock de concorrência, aceitável com um operador só, e o histórico do git guardar states antigos, todos cifrados.

Perder a passphrase não derruba nada: o túnel e o DNS continuam existindo na Cloudflare.

O caminho é gerar uma passphrase nova e reconstruir o state com `tofu import` de cada recurso do módulo. Trocar a passphrase de propósito usa um bloco `fallback` com a antiga durante uma execução, que lê com a antiga e grava com a nova.

Ninguém digita a passphrase. `just tofu-state-passphrase` a gera com `openssl rand -base64 48`.

Ela entrega direto ao `sops encrypt` por um pipe.

O valor nunca aparece no terminal, nunca vai para argumento de processo e nunca toca o disco em texto claro; gerar uma do zero nem exige identidade que decifre, porque cifrar só usa as chaves públicas.

O script recusa gerar outra por cima quando algum `terraform.tfstate` já existe, porque uma passphrase nova trancaria esses states.

Para esse caso existem `--rotate`, que guarda a atual como `TF_VAR_state_passphrase_previous` antes de gerar a nova.

Existe também `--finish-rotation`, que descarta a antiga depois que todo módulo regravou o state; ambos precisam decifrar a atual, então pedem a identidade do operador.

A passphrase é uma só para todo módulo. Passphrases separadas não isolariam nada de verdade, porque quem decifra um arquivo SOPS deste repositório decifra todos.

O bloco `encryption`, por outro lado, fica repetido em cada root module, de propósito.

O OpenTofu aceitaria a mesma configuração pela variável de ambiente `TF_ENCRYPTION`, sem repetir HCL, mas aí a cifragem dependeria de rodar pela recipe: um `tofu apply` executado à mão, sem a variável, não teria configuração de cifragem nenhuma e gravaria o state em texto claro.

Com o bloco no HCL e `enforced = true`, esse engano vira erro em vez de vazamento.

## Valores de exemplo que não podem passar batido

Todo segredo novo nasce com um valor de exemplo começando com `REPLACE_WITH_`, cifrado, e a CI não tem como distinguir um valor de exemplo cifrado de um real.

Sem proteção, o caso mais perigoso passaria calado: o valor de exemplo da passphrase é longo o bastante para passar na validação de tamanho, então o OpenTofu cifraria o state com uma frase adivinhável, e o state commitado ficaria, na prática, aberto.

Camadas independentes fecham isso. As variáveis do módulo recusam passphrase começando com `REPLACE_WITH_`, ID fora do formato hexadecimal de tamanho fixo que a Cloudflare usa, e hostname terminado em `.invalid`.

Isso vale no `plan` mesmo com `tofu` rodado à mão, antes de qualquer chamada à API.

O `tofu-run.sh` recusa rodar se qualquer segredo decifrado ainda começar com `REPLACE_WITH_`, o que cobre o API token, que o provider lê direto do ambiente, sem passar por variável.

A última camada é a única que enxerga o conteúdo cifrado. `just placeholders` decifra em memória todo arquivo SOPS do repositório, incluindo o `secrets.sops.yaml` do Ansible.

Ele lista os nomes das chaves que ainda têm valor de exemplo (nunca os valores), procura valores de exemplo em texto claro e confere que o hostname de `terraform.tfvars` é o mesmo do `PUBLIC_SITE_BASE_URL` do blog.

Ela fica fora da CI pelo mesmo motivo de sempre: precisa de uma identidade que decifre.

A parte que não precisa decifrar, valores de exemplo em texto claro e o hostname divergente, é o job `placeholders` da CI, descrito em [a pipeline de CI](ci.md), e falha o push em vez de esperar alguém rodar a recipe.

O `just placeholders` ([.tools/check-placeholders.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-placeholders.sh)) decifra em memória também `ansible/group_vars/all/secrets.sops.yaml`, onde ficam o token do k3s e o segredo do webhook.

O motivo é o mesmo que decifra os de `tofu/`: um valor de exemplo esquecido dentro de um arquivo cifrado não aparece em nenhum lint de texto claro.

O token do k3s é o caso mais incômodo dessa lista, porque um valor de exemplo ali não quebra nada de imediato: o cluster sobe, funciona, e só a entrada de um segundo node revelaria que o segredo que autoriza o join é público.

O segredo do webhook falha de forma parecida, entregando ao GitHub uma assinatura que qualquer um poderia forjar.

## Um segundo módulo: a tailnet

[tofu/tailscale](https://github.com/guesant/hl-infrastructure/tree/main/tofu/tailscale) segue exatamente o mesmo molde, com outro provider.

O `versions.tf` pina `tailscale/tailscale` numa versão exata.

O encryption.tf é uma cópia do da Cloudflare.

`tofu/tailscale/tailscale.sops.env` guarda as credenciais do provider (um OAuth client, que ao contrário de um API key não expira por tempo e aceita escopo só de DNS e leitura de dispositivos) para o mesmo `tofu-run.sh` decifrar em memória.

Repetir o molde inteiro, em vez de extrair um módulo compartilhado, é decisão consciente: são poucos arquivos, e um módulo comum faria uma mudança na cifragem de um provider alcançar o outro sem que ninguém tivesse pedido.

O que vale a pena repetir é o que precisa ser verificável isoladamente, e a configuração de cifragem do state é exatamente esse caso.

O módulo declara uma coisa só na conta do Tailscale: o split DNS que aponta `guesant.internal` para o endereço do node na tailnet.

O search path fica de fora porque é uma lista única da tailnet, e o recurso do provider a substitui inteira; o split DNS, ao contrário, é um recurso por domínio, então os que o operador já tem para outros domínios não são tocados.

O endereço ele lê pelo data source `tailscale_device`, procurando o node pelo hostname que a role `tailscale` anuncia.

Isso vem com `wait_for` configurado para o caso de o node ter acabado de entrar.

Por isso o `plan` só faz sentido depois do bootstrap ter ligado o node.

O state cifrado desse módulo só revela o hostname do node e um endereço `100.x` que não existe fora da tailnet. O que ele não declara, de propósito, é a ACL: veja [Tailscale: acesso remoto e DNS interno](tailscale.md).

## Módulos do Keycloak, um por realm

O Keycloak tem realms com papéis distintos, e o repositório tem um módulo para cada um.

`master` é só do próprio Keycloak: nele vivem o administrador permanente do operador e as contas de serviço; nenhum usuário de aplicação, nenhum client de ferramenta.

`homelab` é o realm do blog: quem administra `guesant.net`, e o client blog.

`management` é o realm das ferramentas internas: quem opera o node entra ali, e os clients `argocd, grafana, portainer, oauth2-proxy` autenticam contra ele.

Separar quem lê o blog de quem administra o cluster é o motivo da divisão: são populações diferentes, com políticas de sessão e de acesso que podem divergir sem afetar uma à outra, e um comprometimento de um client do blog não dá a ninguém um token válido nas ferramentas.

`tofu/keycloak-master` é o módulo que se roda raramente e com a credencial mais forte.

Ele entra com o administrador de bootstrap que o pod do Keycloak cria a partir do Secret `keycloak-bootstrap-admin` quando o realm `master` ainda está vazio.

Ele também declara os realms `homelab, management`, um usuário admin permanente no `master` e as contas de serviço dos outros módulos.

A assimetria é o ponto: este é o único módulo que cria realm, e os demais só preenchem o que ele criou, usando credenciais que ele emitiu.

Um comprometimento de uma conta de serviço, portanto, alcança o conteúdo de um realm, não a existência dele nem os outros realms.

Os realms nascem com as mesmas configurações de sessão, proteção contra força bruta e política de passkeys.

A política é a `web_authn_passwordless_policy`, com `passwordless_passkeys_enabled` ligado.

`discoverable_credential, user_verification_requirement` ficam em `required`, os mesmos valores que o próprio Keycloak assume ao ligar "Enable Passkeys" pelo console.

As configurações de sessão e a proteção contra força bruta vivem no próprio `.tf` de cada realm, com o tempo de vida do token de acesso, a janela de sessão ociosa e máxima, o limite de tentativas de login erradas e o tempo de bloqueio.

É o lugar para confirmar se um usuário bloqueado ou uma sessão expirada é o comportamento esperado, sem precisar adivinhar o valor.

O `homelab` chegou a entrar por `import`, mas foi recriado pelo próprio módulo, e nenhum bloco import sobrou.

O `admin` permanente do `master` tem o papel admin e uma senha longa.

Essa senha vem do `keycloak-master.sops.env`, e o admin passa a ser o break-glass da instância.

As contas de serviço são os clients confidenciais `tofu-homelab, tofu-management`.

Cada uma tem apenas os papéis de gerenciamento do seu realm no client `<realm>-realm` do `master`.

O título de cada realm (`display_name`, o que aparece na tela de login) também é deste módulo.

O do `master` continua fora do Tofu, porque trazê-lo exigiria um `import` do realm que já existe e arriscaria resetar para o padrão do schema alguma configuração dele que este repositório nunca declarou.

Depois do primeiro `apply`, `just keycloak-bootstrap-admin` apaga o temp-admin pela API.

A recipe também regrava o `.sops.env` deste módulo com o administrador permanente, de modo que o módulo nunca mais dependa de nada que o operator gerou; ela é idempotente e termina conferindo um `plan` vazio.

A política de passkeys por si só só torna o registro possível; ela não muda o fluxo de login.

Sem um fluxo de autenticação próprio, um usuário com passkey cadastrada continua caindo no formulário de usuário e senha, seguido de TOTP quando configurado, porque é isso que o fluxo `browser` padrão do Keycloak sempre executa.

`tofu/keycloak-master/passwordless-flow.tf` declara, para os realms `homelab, management`, um fluxo browser passwordless.

Esse fluxo copia a estrutura do browser padrão: cookie de sessão e redirecionamento de identity provider como alternativas de topo, depois um subfluxo de formulários com usuário e senha obrigatórios e um subfluxo condicional de TOTP.

Ele acrescenta o autenticador `webauthn-authenticator-passwordless` como mais uma alternativa de topo.

Ele liga esse fluxo novo como o `browser_flow` do realm por `keycloak_authentication_bindings`.

Isso é o que permite ao usuário com passkey cadastrada pular o usuário e senha por completo: as alternativas de um fluxo do Keycloak são avaliadas em conjunto, e a primeira que o navegador consegue completar decide o caminho, então quem tem uma passkey passa direto por ela e quem não tem cai no formulário de sempre.

`tofu/keycloak-homelab, tofu/keycloak-management` são o mesmo desenho aplicado a realms diferentes, e por isso são quase idênticos em código.

Cada um autentica com a sua conta de serviço (`client_credentials`, sem senha de humano), e lê o realm com um `data source` em vez de possuí-lo.

Cada um declara o conteúdo: o grupo `admins`, a required action que obriga TOTP a todo usuário, e a required action `webauthn-register-passwordless` (não obrigatória, fica disponível para o usuário registrar um passkey por conta própria no Account Console).

Cada um também declara o escopo `groups` com o mapper de pertencimento, e os clients com seus redirects e escopos padrão.

O client do blog é o client administrativo do `admin.guesant.net`. Seu `base_url` é `https://admin.<blog_hostname>`, o callback de login é `/auth/keycloak/callback` e o logout retorna para a raiz desse mesmo hostname. O site público não participa desse callback: a autenticação do painel e a sessão editorial ficam isoladas no domínio administrativo.

Todos os clients exigem PKCE exceto o `portainer`, porque a edição livre do Portainer não o envia.

Quase todos são confidenciais, com um segredo que vive num SopsSecret e chega ao módulo pelo `secrets.map`.

O `kargo` é a exceção, um client público sem segredo, porque o Kargo autentica só com Authorization Code e PKCE, tanto na UI quanto no CLI (daí o segundo redirect, em `localhost`), e um segredo num client que roda no navegador não protegeria nada.

Os dois módulos serem quase idênticos é um sinal de que a divisão está no lugar certo: o que muda entre eles são os clients e os redirects, não a forma de declarar identidade. Uma diferença que aparecesse no código dos dois, e não nos valores, seria motivo para perguntar se ela deveria existir em ambos.

Não há provedor de identidade externo, e não há usuário declarado: usuário é dado operacional, não configuração, e quem os cria é o operador, no console do Keycloak, entrando como o `admin` do `master`.

O que o git decide é a regra: quem estiver no grupo `admins` de um realm entra nas aplicações dele, porque é esse grupo, no claim `groups`, que cada consumidor confere; quem não estiver, autentica e é recusado.

Um usuário criado no console precisa de um e-mail preenchido, porque Grafana e oauth2-proxy exigem esse claim, e de estar no grupo; a senha e o TOTP ele cadastra no login inicial.

Ambos os módulos criam tudo do zero: o realm `homelab` original, vindo do `KeycloakRealmImport`, foi substituído pelo Tofu porque nasceu sem os escopos padrão do Keycloak.

Os clients `argocd, grafana` que viviam nele foram removidos depois que o realm `management` passou a servi-los.

Uma diferença deliberada em relação ao realm importado: os clients passam a ter os escopos padrão do Keycloak (`profile, email, roles, web-origins, acr, basic`) além de `groups`.

O import original os deixou só com `groups`.

Sem `basic/email`, um token não carrega nem o `sub` nem o e-mail.

A falha desse tipo é difícil de diagnosticar porque o login funciona: o Keycloak autentica, devolve um token, e é o consumidor que recusa depois, reclamando de um claim ausente.

Declarar os escopos no módulo, em vez de herdá-los de um import, é o que garante que o realm recriado do zero nasça igual ao que está rodando.

A escolha pelo OpenTofu, e não por um reconciliador dentro do cluster, foi deliberada: `plan` legível antes de cada mudança e state explícito, ao custo de o realm só reconciliar quando o operador roda o módulo.

A importação do operator (`KeycloakRealmImport`) rodava uma vez só, e foi assim que os clients ficaram com redirects para um endereço da rede local que já não existe enquanto o git dizia outra coisa; ela saiu do repositório, e num cluster vazio quem cria os realms é o `apply` de cada módulo.

O custo dessa escolha é o que a janela entre duas execuções permite: alguém pode mudar um client pelo console e o git não percebe até o próximo `plan`. É um risco tolerável com um operador só, e a contrapartida é que toda mudança de identidade passa por um diff antes de existir.

Os módulos falam com o Keycloak pelo nome interno da tailnet, confiando na CA interna pelo `internal-ca.crt` commitado ao lado, que é o certificado público, não um segredo.

O `client_timeout` é alongado, porque criar um realm no Raspberry Pi passa do tempo que o provider espera por padrão.

A primeira criação do `management` estourou esse limite depois de o Keycloak já o ter gravado, e o realm entrou por import na tentativa seguinte.

O episódio deixa duas lições que valem além deste módulo: um timeout estourado não significa que a operação não aconteceu, e um `apply` que falha desse jeito pede conferir o estado real antes de tentar de novo.

Falar pelo nome interno também amarra o módulo à tailnet, o que é deliberado, já que o console de administração não existe fora dela.

O provider é o `keycloak/keycloak`, mas ele não vem do registro: o registro do OpenTofu não tem a chave que assina esse provider e o `init` o recusa.

`.tools/tofu-mirror.sh` baixa o zip de cada plataforma direto da release no GitHub, e confere contra o `SHA256SUMS` publicado.

Ele guarda o resultado em `.cache/tofu/mirror`, ignorado pelo git.

`tofu-run.sh, tofu-validate.sh` apontam o OpenTofu para esse espelho só para `keycloak/*` (o resto continua vindo do registro).

O `.terraform.lock.hcl` commitado fixa o hash de cada zip, então um espelho adulterado falha no `init`.

O nome antigo do provider, `mrparkers/keycloak`, o registro verifica, mas a versão que existe lá para de funcionar com contas de serviço.

O Keycloak 26.4 esconde a versão do servidor em `/admin/serverinfo` de quem não é admin do `master`, e o provider antigo aborta o login sem ela.

O novo aceita `keycloak_version` como valor de reserva, declarado em cada `versions.tf` com a versão da imagem do Keycloak.

Nenhum segredo de client existe em mais de uma cópia. Cada módulo pode trazer, ao lado do `.sops.env`, um `secrets.map`: uma linha por variável, dizendo de qual arquivo SOPS do repositório e de qual chave dentro dele o valor vem.

O `.tools/tofu-run.sh` lê o mapa no Mac do operador.

Ele extrai cada valor com `sops --decrypt --extract` (só em memória, como já faz com o `.sops.env`).

Ele entrega o valor ao container como variável de ambiente.

Assim o `SopsSecret` que o consumidor monta é a única fonte do client secret que o Keycloak recebe.

`tofu/keycloak-management` lê o segredo de cada client confidencial dos SopsSecret das `Application`.

Isso vale para `sso, portainer, oauth2-proxy`.

Os módulos de realm leem do `keycloak-master.sops.env` o segredo da própria conta de serviço, declarado lá.

A distribuição dos arquivos segue disso: só o módulo `master` tem um `.sops.env` próprio, e os outros não têm nenhum, porque tudo de que precisam já está cifrado em algum lugar do repositório.

Uma rotação passa a ser editar um arquivo e aplicar, em vez de caçar as cópias do mesmo valor. O sentido da leitura também importa aqui, porque o consumidor é quem detém o segredo e o Keycloak é quem o recebe, e não o contrário.

## Na CI e no Renovate

O job `tofu` roda `tofu fmt -check`, e as políticas do Conftest em [.config/conftest/tofu](https://github.com/guesant/hl-infrastructure/tree/main/.config/conftest/tofu).

Essas políticas cobrem todo registro DNS atrás do proxy da Cloudflare, `prevent_destroy` no apex e no www, túnel remotamente gerenciado, cifragem de state e plan com `enforced` e provider pinado em versão exata.

Para cada módulo em `tofu/`, ele roda `tofu validate`.

Isso usa `init -backend=false`.

A inicialização dos providers tem retries limitados para absorver indisponibilidades transitórias do registro ou das releases sem ignorar falhas persistentes.

Isso usa uma passphrase fictícia, sem credencial nenhuma.

[.tools/tofu-validate.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/tofu-validate.sh) é o mesmo script do `just lint-tofu`.

Ele valida uma cópia de cada módulo só com `.tf, .tfvars` e o lock, deliberadamente sem o `terraform.tfstate`.

O `init` lê o state local mesmo com `-backend=false`, e o state commitado, cifrado com a passphrase real, faria a validação falhar contra a passphrase fictícia que o script usa só para satisfazer a configuração de cifragem.

O container roda com o uid e o gid de quem chama, porque no Linux do CI ele rodaria como root e deixaria o `.terraform` da cópia com um dono que o runner não consegue apagar.

O `trivy config` inclui o scanner de Terraform sobre o repositório. `plan` na CI ficou de fora de propósito: exigiria dar à CI uma chave capaz de decifrar o API token.

O Renovate atualiza o provider e o `.terraform.lock.hcl` pelo gerenciador nativo, respeitando a maturidade mínima declarada em `.github/renovate.json` (a razão de o provider estar pinado numa versão exata, já que minors do provider v5 da Cloudflare mudaram schema de recursos de túnel).

Ele também atualiza `opentofu_version` no `justfile` por um gerenciador de regex.

`required_version` fica fora do Renovate porque ele o compararia com versões do Terraform, não do OpenTofu.

A consequência de deixá-lo de fora é que ele envelhece por conta própria e precisa ser revisado à mão de tempos em tempos, o que é preferível a receber sugestões de bump para a versão errada de ferramenta.

O `opentofu_version` do `justfile`, que é o que de fato decide qual imagem roda, continua acompanhado, então a versão em uso nunca fica sem manutenção.

## Continue por aqui

O passo a passo para criar o API token e aplicar pela primeira vez está em [primeiro bootstrap](../operacional/primeiro-bootstrap.md); rotacionar o token do túnel ou o API token está em [rotacionar credenciais](../operacional/rotacionar-credenciais.md).
