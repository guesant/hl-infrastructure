# OpenTofu: a camada da Cloudflare

<!-- source-of-trust paths="tofu/*/*.tf tofu/*/terraform.tfvars .tools/tofu-run.sh .tools/tofu-state-passphrase.sh .tools/cloudflare-tunnel-token.sh .tools/check-placeholders.sh .tools/tofu-validate.sh" -->

O Ansible prepara o node e o Argo CD cuida de tudo que roda dentro do cluster, mas o caminho de um visitante até o blog começa fora desses sistemas: no DNS da Cloudflare e no túnel que liga a borda da Cloudflare ao cloudflared dentro do cluster. [tofu/cloudflare](https://github.com/guesant/hl-infrastructure/tree/main/tofu/cloudflare) declara essa parte com OpenTofu, e o resto desta página explica o que ele possui, o que ele deliberadamente não possui e por quê.

O título da página ficou estreito com o tempo: a mesma mecânica passou a declarar o split DNS da tailnet e os realms do Keycloak, cada um no seu módulo, e as seções finais tratam desses dois. O que reúne os três casos não é o provider, e sim a situação: estado que vive na conta de um serviço de terceiro, sem nada dentro do cluster para reconciliá-lo.

## O que o OpenTofu declara

O túnel do blog, a configuração de ingress desse túnel e os registros CNAME apontando para o endereço do túnel: os do blog, no domínio raiz e no `www`, que servem o mesmo conteúdo sem redirect, e o de operação. O CNAME no apex funciona porque a Cloudflare o achata num endereço na hora de responder o DNS, sem precisar de registro A.

Os registros do apex e do `www` têm proteção contra destruição: um plano que os destruiria, seja por um recurso removido do código, seja por uma mudança que obrigue recriar, falha antes do apply, porque apagar esses registros tira o blog do ar.

Os CNAME do domínio raiz e do `www` já existiam antes do OpenTofu, apontando para o site antigo na Vercel. Em vez de apagá-los e recriá-los, eles foram trazidos para o state por importação, e a virada para o túnel foi um apply que só trocou o destino.

A ordem evitou queda: primeiro o túnel, o ingress e o registro de operação, aplicados isoladamente; depois o token do túnel no cluster e o cloudflared conectado; só então a troca do destino do apex e do `www`, sempre a partir de um plano salvo e conferido antes do apply.

O túnel é remotamente gerenciado: as regras de ingress moram na própria Cloudflare, e o cloudflared no cluster não carrega arquivo de configuração nenhum, só o token que o identifica. O webhook do GitHub chega pelo domínio de operação, e a regra casa só o caminho exato do webhook antes de mandar para o servidor do Argo CD.

O destino usa a porta segura, e não a insegura, por um motivo que não aparece em nenhum lint: sem o modo inseguro habilitado, o servidor do Argo CD responde a qualquer requisição HTTP com um redirect para HTTPS, e o GitHub não segue redirect em webhook, então toda entrega falharia. O certificado desse servidor é autoassinado, por isso a regra liga a opção que ignora verificação de TLS, só nela e num trecho que não sai do cluster.

O túnel não reescreve caminho: ele escolhe esquema, host e porta do destino, mas encaminha o caminho do jeito que chegou. Qualquer outro caminho nesse hostname cai em página não encontrada, então a interface e a API do Argo CD nunca ficam expostas; apontar o hostname inteiro para o servidor publicaria interface e API na internet.

O domínio do blog vai inteiro para o serviço correspondente no cluster, e qualquer outro hostname recebe a mesma recusa. Separar os hostnames tira o tráfego de operação do site público: nenhuma rota do blog colide com o webhook, e regras da Cloudflare, como WAF ou Access, podem valer só para o de operação. Uma validação do módulo recusa usar o mesmo hostname para blog e operação.

O domínio de autenticação leva ao Keycloak pelo mesmo túnel, mas a regra de ingress casa só os caminhos de realm e recurso, que são as páginas de login, os endpoints OIDC e os arquivos estáticos delas.

Qualquer outro caminho nesse hostname, incluindo o console de administração, cai na regra final e recebe a mesma recusa na borda da Cloudflare, sem chegar ao cluster. As validações da variável recusam um hostname igual ao do blog ou ao de operação, para que o provedor de identidade nunca divida hostname com outro tráfego.

Um ruleset de cache torna tudo sob o caminho do runtime da aplicação elegível a cache na borda respeitando o TTL da origem.

Sem ele a Cloudflare tratava o runtime WebAssembly do blog, um arquivo de alguns megabytes com nome por fingerprint e cabeçalho imutável, como conteúdo dinâmico, e cada visitante novo o baixava do Raspberry Pi pelo túnel; essa extensão não está na lista padrão do que a Cloudflare cacheia, ao contrário das extensões comuns de script e estilo, que já voltavam como acerto de cache.

O ganho é maior do que economia de banda: cada megabyte servido da borda é um megabyte que o Raspberry Pi não empacota nem empurra pelo túnel, e é justamente esse arquivo que todo visitante novo precisa antes de a página funcionar. A regra é por prefixo de caminho, e não por extensão, para que um runtime com outro formato continue coberto sem mexer aqui.

O WAF declara hoje um ruleset só, de rate limit, dentro dos limites do plano gratuito da zona. Um segundo ruleset, de regras customizadas, chegou a existir: ele bloqueava varreduras por software que esta zona não roda e restringia o domínio de operação ao verbo correto no caminho do webhook.

A Cloudflare recusou esse ruleset no plano gratuito da zona, e ele foi removido do código; essa fase de regra customizada exige um plano pago. A restrição do domínio de operação não ficou descoberta por isso, porque a regra de ingress do túnel, descrita acima, já limita esse hostname ao mesmo caminho exato e devolve a mesma recusa para qualquer outro;

o que ficou sem cobertura foi só o bloqueio de varreduras por caminho de software que esta zona não roda, e hoje nada barra essas requisições na borda da Cloudflare antes de chegarem ao túnel, onde caem na recusa do hostname correspondente como cairia qualquer caminho inexistente.

O ruleset de rate limit que sobrou bloqueia temporariamente um IP que exceder o limite de requisições declarado nos fluxos de login do Keycloak; a expressão usa só o caminho, sem o hostname, porque no plano gratuito uma regra de rate limit só pode filtrar pelo campo de caminho, e esses caminhos só existem no Keycloak.

Ele não cobre os endpoints de token e de descoberta, porque o Argo CD, o Grafana e o blog os chamam do mesmo IP de saída do node e seriam bloqueados junto.

Esse é o limite real de um rate limit por IP num cluster de um nó só: todo tráfego servidor a servidor sai com o mesmo endereço, e o que seria proteção passa a bloquear o próprio cluster. Restringir a regra aos caminhos que só um navegador de pessoa percorre é o que mantém a proteção onde ela faz diferença, na tentativa repetida de senha.

Esse desenho cria um acoplamento que nenhum gate pega: os destinos do ingress são nomes de serviço do cluster, declarados em outro sistema. Renomear um desses serviços num chart do Argo sem mudar a configuração do túnel quebra o túnel sem nenhum erro de CI; a mudança precisa ir para ambos os lados no mesmo commit.

O acoplamento não tem como ser eliminado, porque o túnel precisa de um destino e o destino vive no cluster; o que dá para fazer é torná-lo visível, e é por isso que ele está escrito aqui. Vale o mesmo cuidado ao renomear um namespace, já que o nome completo do serviço carrega ambos.

O provider avisa, a cada plano, que a configuração de ingress do túnel não pode ser destruída por ele: remover esse recurso do código, ou destruir o módulo, tira o recurso do state mas deixa a configuração de ingress na API da Cloudflare até alguém apagá-la à mão no dashboard. Para este uso isso não muda nada no dia a dia, mas vale lembrar numa desmontagem do túnel.

É um caso em que o state deixa de descrever a realidade sem que nada acuse: o arquivo diz que o recurso não existe mais, e a API da Cloudflare continua com ele. Se o túnel for reconstruído depois, a configuração antiga ainda está lá para ser sobrescrita, o que costuma ser inofensivo e é péssimo de descobrir sem aviso.

## O que ele não possui, de propósito

O token que o cloudflared usa para se conectar nunca passa pelo OpenTofu. O provider da Cloudflare até oferece um data source que lê esse token, mas qualquer valor lido por um data source vai parar no state, e marcar um atributo como sensível só o esconde da saída do terminal, não o tira do arquivo.

Em vez disso, [.tools/cloudflare-tunnel-token.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/cloudflare-tunnel-token.sh) lê do state só o ID do túnel, pede o token direto à API da Cloudflare e o grava recifrado no `SopsSecret` do cloudflared, sem arquivo intermediário em texto claro. A fonte da verdade desse token é a Cloudflare; o segredo cifrado é uma cópia para entrega.

O API token que autoriza o OpenTofu a mexer na conta também não é recurso dele. É um token único, criado à mão no dashboard, com só as permissões estritamente necessárias, edição de túnel na conta e DNS na zona do blog.

Um token com permissão de criar outros tokens deixaria o OpenTofu gerenciar credenciais, mas seria praticamente a conta inteira num segredo só, e o valor de cada token criado cairia no state; para um operador só, isso aumenta o risco sem resolver problema nenhum.

## Como as credenciais chegam ao processo

Os segredos ficam separados por nível, porque respondem a perguntas diferentes. Um arquivo é comum a todo o OpenTofu e guarda só a passphrase do state, que o OpenTofu recebe pela convenção de prefixo de variável do provider.

Cada módulo guarda as credenciais do próprio provider num arquivo com o nome dele, com o API token da Cloudflare e os IDs da conta e da zona; assim um módulo futuro, de outro provider, nunca recebe o token da Cloudflare no ambiente.

Os IDs não são credencial, mas ficam cifrados para este repositório público não apontar para a conta, e as variáveis que os recebem são sensíveis, então nem o plan nem o apply os imprimem. O hostname do blog continua em texto claro na declaração de valores: ele é público de qualquer jeito, pelo DNS e pelos logs de certificado TLS, e cifrá-lo só esconderia algo que o próprio site anuncia.

| Arquivo ou variável | Guarda |
| --- | --- |
| `tofu/state.sops.env` | `TF_VAR_state_passphrase`, comum a todo módulo |
| `tofu/cloudflare/cloudflare.sops.env` | API token da Cloudflare e os IDs de conta e zona |
| `CLOUDFLARE_API_TOKEN_READ` | Token de escopo só leitura, usado nos subcomandos que não escrevem |
| `terraform.tfvars` | Hostname do blog, em texto claro de propósito |

A recipe de OpenTofu chama um script que se reexecuta por dentro de uma decifragem em ambiente para cada arquivo de segredo envolvido: cada uma decifra os valores só no ambiente do processo filho. No fim, o script roda a imagem oficial do OpenTofu, passando exatamente as variáveis que esses arquivos declaram, sem valor explícito, para que o container herde a variável do ambiente em vez de recebê-la na linha de comando.

Assim o segredo nunca toca o disco nem aparece em log de processo. O custo de mais de um arquivo é a Secure Enclave poder pedir biometria mais de uma vez por execução. A decifragem acontece no host, e não dentro do container, pelo mesmo motivo das recipes de segredo já descritas: a identidade de rotina do operador vive na Secure Enclave do Mac e não funciona fora dele.

O plan não precisa escrever nada na Cloudflare, e um token que só lê diminui o estrago de um plan rodado sobre um módulo alterado por engano ou por um provider comprometido. Por isso o script olha o subcomando: nos comandos só de leitura, se o arquivo de segredos declarar um token de leitura próprio, é esse o valor que o container recebe como token da API; o de escrita nem chega a ser passado.

Nos demais comandos, apply e import principalmente, vai o token de escrita. Enquanto o token de leitura não existir, os comandos de leitura avisam e seguem com o de escrita, para que a separação possa ser ligada depois sem quebrar nada; criá-lo no dashboard e gravá-lo é passo manual do operador.

O provider de SOPS para OpenTofu, que decifraria o arquivo de dentro do próprio OpenTofu, ficou de fora. Configuração de provider não é gravada no state, então a decifragem em ambiente já mantém o API token fora dele; nenhum recurso do módulo recebe segredo como argumento, então recursos efêmeros e atributos write-only não teriam onde ajudar; e decifrar dentro do container esbarraria na Secure Enclave de novo.

O provider resolveria um problema que este repositório não tem, porque a decifragem já acontece antes do OpenTofu começar, e traria uma dependência a mais para pinar, atualizar e confiar. Recusá-lo custa uma linha a mais no script que reexecuta o comando, e é o tipo de troca que vale quando a alternativa é aumentar a superfície do que roda com credencial de escrita.

A regra do SOPS para os arquivos de ambiente do OpenTofu é separada da regra dos segredos cifrados de manifesto Kubernetes, e não usa o mesmo sufixo. Isso não é detalhe: a regra dos manifestos só cifra o que está sob o campo de dados do segredo, e um arquivo de ambiente que caísse nela sairia "cifrado" com todo valor em texto claro. O gate de segredos cifrados confere ambos os tipos de arquivo.

Um módulo pode ainda declarar um mapa de segredos, com variáveis que vêm de outros arquivos SOPS do repositório em vez do seu próprio arquivo de ambiente; o mesmo script as extrai e as entrega da mesma forma. É como os módulos do Keycloak leem os client secrets dos segredos que os consumidores montam, sem cópia.

A alternativa seria repetir cada client secret num arquivo do módulo, e duas cópias de um segredo significam duas rotações, das quais uma cedo ou tarde é esquecida. O mapa custa um arquivo de texto com uma linha por variável, legível em revisão, que diz exatamente de onde cada valor vem.

## State cifrado dentro do git

O state fica commitado, cifrado pela state encryption nativa do OpenTofu: uma chave derivada da passphrase, um método de cifragem autenticada, e a exigência de cifragem obrigatória tanto para state quanto para plan, o que faz o OpenTofu recusar gravar state ou plan em texto claro se a configuração de cifragem sumir.

Commitar evita um serviço novo só para guardar um arquivo pequeno, e o que ele contém é pouco sensível mesmo decifrado, IDs de conta, zona e túnel, e os registros DNS, justamente porque nenhum token passa pelo OpenTofu. O custo é não ter lock de concorrência, aceitável com um operador só, e o histórico do git guardar states antigos, todos cifrados.

Perder a passphrase não derruba nada: o túnel e o DNS continuam existindo na Cloudflare. O caminho é gerar uma passphrase nova e reconstruir o state por importação de cada recurso do módulo. Trocar a passphrase de propósito usa um bloco de reserva com a antiga durante uma execução, que lê com a antiga e grava com a nova.

Ninguém digita a passphrase. A recipe correspondente a gera aleatoriamente e a entrega direto ao SOPS por um pipe, então o valor nunca aparece no terminal, nunca vai para argumento de processo e nunca toca o disco em texto claro; gerar uma do zero nem exige identidade que decifre, porque cifrar só usa as chaves públicas.

O script recusa gerar outra por cima quando algum state já existe, porque uma passphrase nova trancaria esses states. Para esse caso existem uma flag de rotação, que guarda a atual antes de gerar a nova, e uma flag de conclusão, que descarta a antiga depois que todo módulo regravou o state; ambas precisam decifrar a atual, então pedem a identidade do operador.

| Flag ou variável | Papel |
| --- | --- |
| `--rotate` | Guarda a passphrase atual como `TF_VAR_state_passphrase_previous`, gera a nova |
| `--finish-rotation` | Descarta a passphrase antiga depois de todo módulo regravado |
| `TF_ENCRYPTION` | Alternativa de ambiente ao bloco HCL repetido, deliberadamente não usada |

A passphrase é uma só para todo módulo. Passphrases separadas não isolariam nada de verdade, porque quem decifra um arquivo SOPS deste repositório decifra todos.

O bloco de cifragem, por outro lado, fica repetido em cada root module, de propósito: o OpenTofu aceitaria a mesma configuração pela variável de ambiente da tabela acima, sem repetir HCL, mas aí a cifragem dependeria de rodar pela recipe; um apply executado à mão, sem a variável, não teria configuração de cifragem nenhuma e gravaria o state em texto claro. Com o bloco no HCL e a exigência de cifragem obrigatória, esse engano vira erro em vez de vazamento.

## Valores de exemplo que não podem passar batido

Todo segredo novo nasce com um valor de exemplo cifrado, e a CI não tem como distinguir um valor de exemplo cifrado de um real. Sem proteção, o caso mais perigoso passaria calado: o valor de exemplo da passphrase é longo o bastante para passar na validação de tamanho, então o OpenTofu cifraria o state com uma frase adivinhável, e o state commitado ficaria, na prática, aberto. Camadas independentes fecham isso.

As variáveis do módulo recusam passphrase de exemplo, ID fora do formato que a Cloudflare usa e hostname sob o domínio reservado, e isso vale no plan mesmo rodado à mão, antes de qualquer chamada à API. O script que reexecuta o comando recusa rodar se qualquer segredo decifrado ainda for um valor de exemplo, o que cobre o API token, que o provider lê direto do ambiente, sem passar por variável.

A última camada é a única que enxerga o conteúdo cifrado. A recipe local de placeholders decifra em memória todo arquivo SOPS do repositório, incluindo o do Ansible, lista os nomes das chaves que ainda têm valor de exemplo, nunca os valores, procura valores de exemplo em texto claro e confere que o hostname declarado é o mesmo da URL pública do blog.

Ela fica fora da CI pelo mesmo motivo de sempre: precisa de uma identidade que decifre. A parte que não precisa decifrar, valores de exemplo em texto claro e o hostname divergente, é o job correspondente da CI, descrito em [a pipeline de CI](ci.md), e falha o push em vez de esperar alguém rodar a recipe.

A mesma recipe local decifra em memória também o segredo do Ansible, onde ficam o token do k3s e o segredo do webhook, pelo mesmo motivo que decifra os do OpenTofu: um valor de exemplo esquecido dentro de um arquivo cifrado não aparece em nenhum lint de texto claro.

O token do k3s é o caso mais incômodo dessa lista, porque um valor de exemplo ali não quebra nada de imediato: o cluster sobe, funciona, e só a entrada de um segundo node revelaria que o segredo que autoriza o join é público. O segredo do webhook falha de forma parecida, entregando ao GitHub uma assinatura que qualquer um poderia forjar.

## Um segundo módulo: a tailnet

[tofu/tailscale](https://github.com/guesant/hl-infrastructure/tree/main/tofu/tailscale) segue exatamente o mesmo molde, com outro provider: a versão do provider é pinada exata, a configuração de cifragem é uma cópia da do módulo da Cloudflare, e um arquivo próprio guarda as credenciais do provider, um OAuth client, que ao contrário de um API key não expira por tempo e aceita escopo só de DNS e leitura de dispositivos, para o mesmo script decifrar em memória.

Repetir o molde inteiro, em vez de extrair um módulo compartilhado, é decisão consciente: são poucos arquivos, e um módulo comum faria uma mudança na cifragem de um provider alcançar o outro sem que ninguém tivesse pedido. O que vale a pena repetir é o que precisa ser verificável isoladamente, e a configuração de cifragem do state é exatamente esse caso.

O módulo declara uma coisa só na conta do Tailscale: o split DNS que aponta o domínio interno para o endereço do node na tailnet. O search path fica de fora porque é uma lista única da tailnet, e o recurso do provider a substitui inteira; o split DNS, ao contrário, é um recurso por domínio, então os que o operador já tem para outros domínios não são tocados.

O endereço ele lê por um data source do provider, procurando o node pelo hostname que a role correspondente do Ansible anuncia, com uma espera configurada para o caso de o node ter acabado de entrar; por isso o plan só faz sentido depois do bootstrap ter ligado o node.

O state cifrado desse módulo só revela o hostname do node e um endereço que não existe fora da tailnet. O que ele não declara, de propósito, é a ACL: veja [Tailscale: acesso remoto e DNS interno](tailscale.md).

## Módulos do Keycloak, um por realm

O Keycloak tem realms com papéis distintos, e o repositório tem um módulo para cada um.

| Realm | Papel |
| --- | --- |
| `master` | Só do próprio Keycloak: administrador permanente do operador e contas de serviço |
| `homelab` | Do blog: quem administra o domínio público e o client do blog |
| `management` | Das ferramentas internas: Argo CD, Grafana, Portainer e oauth2-proxy autenticam contra ele |

Separar quem lê o blog de quem administra o cluster é o motivo da divisão: são populações diferentes, com políticas de sessão e de acesso que podem divergir sem afetar uma à outra, e um comprometimento de um client do blog não dá a ninguém um token válido nas ferramentas.

O módulo do `master` é o que se roda raramente e com a credencial mais forte. Ele entra com o administrador de bootstrap que o pod do Keycloak cria a partir de um segredo cifrado quando esse realm ainda está vazio, e declara os outros dois realms, um usuário administrador permanente nele e as contas de serviço dos outros módulos.

A assimetria é o ponto: este é o único módulo que cria realm, e os demais só preenchem o que ele criou, usando credenciais que ele emitiu. Um comprometimento de uma conta de serviço, portanto, alcança o conteúdo de um realm, não a existência dele nem os outros realms.

Os realms nascem com as mesmas configurações de sessão, proteção contra força bruta e política de passkeys, os mesmos valores que o próprio Keycloak assume ao ligar essa opção pelo console.

As configurações de sessão e a proteção contra força bruta vivem no próprio módulo de cada realm, com o tempo de vida do token de acesso, a janela de sessão ociosa e máxima, o limite de tentativas de login erradas e o tempo de bloqueio; é o lugar para confirmar se um usuário bloqueado ou uma sessão expirada é o comportamento esperado, sem precisar adivinhar o valor.

O `homelab` chegou a entrar por importação, mas foi recriado pelo próprio módulo, e nenhum bloco de importação sobrou.

O administrador permanente do `master` tem o papel de administrador e uma senha longa vinda do arquivo de segredo do módulo, e passa a ser o break-glass da instância. As contas de serviço são clients confidenciais, cada uma com apenas os papéis de gerenciamento do seu próprio realm.

O título de cada realm, o que aparece na tela de login, também é deste módulo; o do `master` continua fora do Tofu, porque trazê-lo exigiria uma importação do realm que já existe e arriscaria resetar para o padrão do schema alguma configuração dele que este repositório nunca declarou.

Depois do primeiro apply, a recipe de bootstrap do Keycloak apaga o administrador temporário pela API e regrava o arquivo de segredo deste módulo com o administrador permanente, de modo que o módulo nunca mais dependa de nada que o operator gerou; a recipe é idempotente e termina conferindo um plan vazio.

A política de passkeys por si só só torna o registro possível; ela não muda o fluxo de login. Sem um fluxo de autenticação próprio, um usuário com passkey cadastrada continua caindo no formulário de usuário e senha, seguido de TOTP quando configurado, porque é isso que o fluxo `browser` padrão do Keycloak sempre executa.

Um arquivo do módulo do `master` declara, para os outros dois realms, um fluxo alternativo que copia a estrutura do padrão, cookie de sessão e redirecionamento de identity provider como alternativas de topo, depois um subfluxo de formulários com usuário e senha obrigatórios e um subfluxo condicional de TOTP, mas acrescenta o autenticador de passkey como mais uma alternativa de topo, e liga esse fluxo novo como o fluxo de navegador do realm.

Isso é o que permite ao usuário com passkey cadastrada pular o usuário e senha por completo: as alternativas de um fluxo do Keycloak são avaliadas em conjunto, e a primeira que o navegador consegue completar decide o caminho, então quem tem uma passkey passa direto por ela e quem não tem cai no formulário de sempre.

Os módulos do blog e das ferramentas internas são o mesmo desenho aplicado a realms diferentes, e por isso são quase idênticos em código:

cada um autentica com a sua conta de serviço, sem senha de humano, lê o realm em vez de possuí-lo, e declara o conteúdo, o grupo de administradores, a exigência de TOTP a todo usuário, o registro opcional de passkey, o escopo de grupo com o mapper de pertencimento, e os clients com seus redirects e escopos padrão, todos exigindo PKCE exceto o do Portainer, porque a edição livre dele não o envia.

Quase todos são confidenciais, com um segredo que vive num `SopsSecret` e chega ao módulo pelo mapa de segredos; o do Kargo é a exceção, um client público sem segredo, porque o Kargo autentica só com Authorization Code e PKCE, tanto na UI quanto no CLI, e um segredo num client que roda no navegador não protegeria nada.

Os dois módulos serem quase idênticos é um sinal de que a divisão está no lugar certo: o que muda entre eles são os clients e os redirects, não a forma de declarar identidade.

Não há provedor de identidade externo, e não há usuário declarado: usuário é dado operacional, não configuração, e quem os cria é o operador, no console do Keycloak. O que o git decide é a regra: quem estiver no grupo de administradores de um realm entra nas aplicações dele, porque é esse grupo, no claim correspondente, que cada consumidor confere; quem não estiver, autentica e é recusado.

Um usuário criado no console precisa de um e-mail preenchido, porque Grafana e oauth2-proxy exigem esse claim, e de estar no grupo; a senha e o TOTP ele cadastra no login inicial.

Ambos os módulos criam tudo do zero: o realm `homelab` original, vindo da importação do operator, foi substituído pelo Tofu porque nasceu sem os escopos padrão do Keycloak, e os clients de Argo CD e Grafana que viviam nele foram removidos depois que o realm `management` passou a servi-los.

Uma diferença deliberada em relação ao realm importado: os clients passam a ter os escopos padrão do Keycloak além do escopo de grupo; o import original os deixou só com o de grupo, e sem os padrão um token não carrega nem o identificador do sujeito nem o e-mail.

A falha desse tipo é difícil de diagnosticar porque o login funciona: o Keycloak autentica, devolve um token, e é o consumidor que recusa depois, reclamando de um claim ausente. Declarar os escopos no módulo, em vez de herdá-los de um import, é o que garante que o realm recriado do zero nasça igual ao que está rodando.

A escolha pelo OpenTofu, e não por um reconciliador dentro do cluster, foi deliberada: plan legível antes de cada mudança e state explícito, ao custo de o realm só reconciliar quando o operador roda o módulo.

A importação do operator rodava uma vez só, e foi assim que os clients ficaram com redirects para um endereço da rede local que já não existe enquanto o git dizia outra coisa; ela saiu do repositório, e num cluster vazio quem cria os realms é o apply de cada módulo.

O custo dessa escolha é o que a janela entre duas execuções permite: alguém pode mudar um client pelo console e o git não percebe até o próximo plan. É um risco tolerável com um operador só, e a contrapartida é que toda mudança de identidade passa por um diff antes de existir.

Os módulos falam com o Keycloak pelo nome interno da tailnet, confiando na CA interna commitada ao lado, que é o certificado público, não um segredo. O timeout do client é alongado, porque criar um realm no Raspberry Pi passa do tempo que o provider espera por padrão: a primeira criação do `management` estourou esse limite depois de o Keycloak já o ter gravado, e o realm entrou por importação na tentativa seguinte.

O episódio deixa duas lições que valem além deste módulo: um timeout estourado não significa que a operação não aconteceu, e um apply que falha desse jeito pede conferir o estado real antes de tentar de novo. Falar pelo nome interno também amarra o módulo à tailnet, o que é deliberado, já que o console de administração não existe fora dela.

O provider do Keycloak não vem do registro: o registro do OpenTofu não tem a chave que assina esse provider e a inicialização o recusa.

Um script próprio baixa o zip de cada plataforma direto da release no GitHub, confere contra o checksum publicado e o guarda num cache local, ignorado pelo git; os scripts de execução e validação apontam o OpenTofu para esse espelho só para esse provider, o resto continua vindo do registro, e o lock file commitado fixa o hash de cada zip, então um espelho adulterado falha na inicialização.

O nome antigo do provider, o registro verifica, mas a versão que existe lá para de funcionar com contas de serviço: o Keycloak esconde a versão do servidor de quem não é admin do `master`, e o provider antigo aborta o login sem ela. O novo aceita a versão do servidor como valor de reserva, declarado em cada módulo com a versão da imagem do Keycloak.

Nenhum segredo de client existe em mais de uma cópia. Cada módulo pode trazer, ao lado do próprio arquivo de segredo, um mapa de segredos: uma linha por variável, dizendo de qual arquivo SOPS do repositório e de qual chave dentro dele o valor vem. O script de execução lê o mapa no Mac do operador, extrai cada valor só em memória e o entrega ao container como variável de ambiente.

Assim o `SopsSecret` que o consumidor monta é a única fonte do client secret que o Keycloak recebe: o módulo das ferramentas internas lê o segredo de cada client confidencial dos segredos das aplicações correspondentes, e os módulos de realm leem do arquivo do módulo `master` o segredo da própria conta de serviço, declarado lá.

A distribuição dos arquivos segue disso: só o módulo `master` tem um arquivo de segredo próprio, e os outros não têm nenhum, porque tudo de que precisam já está cifrado em algum lugar do repositório. Uma rotação passa a ser editar um arquivo e aplicar, em vez de caçar as cópias do mesmo valor. O sentido da leitura também importa aqui, porque o consumidor é quem detém o segredo e o Keycloak é quem o recebe, e não o contrário.

## Na CI e no Renovate

| Comando | Faz o quê |
| --- | --- |
| `tofu fmt -check` | Falha se algum arquivo não estiver formatado |
| `tofu validate -init -backend=false` | Valida sintaxe e referência sem backend remoto |
| `sops --decrypt --extract` | Extrai um único valor de um arquivo cifrado, sem gravar o resto decifrado |

O job de OpenTofu roda a checagem de formatação, as políticas do Conftest (todo registro DNS atrás do proxy da Cloudflare, proteção contra destruição no apex e no `www`, túnel remotamente gerenciado, cifragem de state e plan obrigatória e provider pinado em versão exata) e, para cada módulo, uma validação com uma passphrase fictícia, sem credencial nenhuma.

O mesmo script do lint local valida uma cópia de cada módulo só com os arquivos de configuração e o lock, deliberadamente sem o state: a inicialização lê o state local mesmo sem backend remoto, e o state commitado, cifrado com a passphrase real, faria a validação falhar contra a passphrase fictícia que o script usa só para satisfazer a configuração de cifragem.

O container roda com o uid e o gid de quem chama, porque no Linux do CI ele rodaria como root e deixaria a pasta de estado da cópia com um dono que o runner não consegue apagar. O trivy de configuração inclui o scanner de Terraform sobre o repositório. O plan na CI ficou de fora de propósito: exigiria dar à CI uma chave capaz de decifrar o API token.

| Item | Fica fora do Renovate porque |
| --- | --- |
| `required_version` | Ele o compararia com versões do Terraform, não do OpenTofu |
| Versão do provider do Keycloak | Já é acompanhada manualmente pelo mesmo motivo do espelho |

O Renovate atualiza o provider e o lock file pelo gerenciador nativo, respeitando a maturidade mínima declarada na configuração do Renovate, a razão de o provider estar pinado numa versão exata, já que minors do provider da Cloudflare mudaram schema de recursos de túnel, e a versão do OpenTofu no `justfile` por um gerenciador de regex.

A consequência de deixar a versão exigida de fora é que ela envelhece por conta própria e precisa ser revisada à mão de tempos em tempos, o que é preferível a receber sugestões de bump para a versão errada de ferramenta; a versão que de fato decide qual imagem roda continua acompanhada, então a versão em uso nunca fica sem manutenção.

## Continue por aqui

O passo a passo para criar o API token e aplicar pela primeira vez está em [primeiro bootstrap](../operacional/primeiro-bootstrap.md); rotacionar o token do túnel ou o API token está em [rotacionar credenciais](../operacional/rotacionar-credenciais.md).
