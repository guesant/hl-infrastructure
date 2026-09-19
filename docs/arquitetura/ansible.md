# Ansible: as roles do bootstrap

<!-- source-of-trust paths="ansible/site.yml ansible/roles" -->

O `site.yml` do Ansible aplica as roles em sequência, numa única play. A ordem importa: cada role assume que a anterior já deixou o sistema num estado específico, e várias delas verificam essa suposição explicitamente antes de continuar.

A sequência tem três trechos, e eles não se misturam: primeiro o sistema operacional; depois a plataforma Kubernetes; por último a role que entrega o cluster ao Argo, e as de manutenção contínua. Cada role também carrega uma tag com o próprio nome, o que permite rodar um trecho isolado sem reordenar nada.

Esta página descreve cada role pelo que ela faz, não pelo nome do diretório; a tabela abaixo é o mapa entre os dois, na ordem real de `ansible/roles/` que `site.yml` aplica.

| Nome descritivo nesta página | Role em `ansible/roles/` |
| --- | --- |
| Pré-requisitos do sistema | `os_prerequisites` |
| Firewall | `firewall` |
| Tailnet | `tailscale` |
| Atualizações automáticas | `unattended_upgrades` |
| Hardening de sysctl | `sysctl_hardening` |
| Umask | `umask_hardening` |
| AppArmor | `apparmor_hardening` |
| Auditoria | `auditd` |
| Hardening de SSH | `ssh_hardening` |
| Fail2ban | `fail2ban` |
| k3s | `k3s` |
| Cilium | `cilium` |
| ArgoCD | `argocd` |
| Bootstrap da aplicação raiz | `bootstrap_app` |
| Chave age | `sops_age_key` |
| Manutenção | `maintenance` |
| kube-bench | `kube_bench` |

## O que toda role faz antes de agir

Cada role começa com uma asserção das variáveis de que depende: versão no formato esperado, chave SSH com prefixo válido e sem o placeholder do exemplo, segredo do webhook com tamanho mínimo, lista de CIDRs bem formada, token do k3s com o tamanho de um valor gerado.

O erro aparece na primeira task, com a mensagem dizendo qual variável e qual formato, em vez de no meio de uma renderização de chart com uma versão vazia. O ganho não é só de mensagem: uma role que aborta na asserção não chegou a mexer em nada no node, então não há estado pela metade para desfazer. É por isso que a verificação fica no início da role, e não junto da task que usa a variável.

Todo recipe do `justfile` que chama o Ansible define a variável de configuração apontando para o arquivo do repositório explicitamente, porque `just` sempre roda a partir da raiz, e essa configuração só é descoberta sozinha quando está no diretório de onde o comando é executado.

Sem essa variável, o vars plugin do SOPS declarado nesse arquivo nunca era carregado, e o arquivo de segredos era lido como um YAML comum, com cada valor cifrado passando para as roles como a string literal em vez do segredo decifrado.

O defeito ficou escondido enquanto um arquivo antigo de segredos em texto claro ainda existia ao lado do cifrado: ambos entram na mesma varredura de variáveis de grupo, o Ansible mescla por ordem alfabética, e o arquivo antigo vinha depois nessa ordem, então seu valor real sobrescrevia silenciosamente o cifrado não decifrado. Só apareceu quando o arquivo antigo foi apagado de vez.

As roles que falam com o cluster embrulham suas tasks num bloco condicionado a um fato que só é verdadeiro numa execução real; sob dry-run num node sem k3s ele é falso, e as roles seguintes pulam o bloco inteiro, para que o dry-run termine limpo e diga a verdade sobre o que pode ser previsto.

A mesma lógica protege o firewalld, e cada serviço systemd só é iniciado em modo de verificação se o pacote já estava instalado antes. O guia [preflight e dry-run](../operacional/preflight-e-dry-run.md) mostra como usar isso.

Os charts do ArgoCD e do Cilium, e a aplicação raiz, seguem o mesmo padrão de sonda mais apply: primeiro uma sonda de diff, sempre real mesmo sob dry-run, porque um diff nunca grava nada, que sai vazia quando o cluster já bate com o manifesto e não vazia quando há diferença; só então a task de apply roda, e só quando a sonda encontrou diferença.

Isso substitui uma versão anterior que decidia se algo mudou procurando uma palavra específica no stdout do próprio apply: greppar o texto de saída de um comando é frágil, e o diff nativo é a própria ferramenta feita pra essa pergunta. Não usar upgrade de release nem comparar values à mão continua valendo: quem decide se há mudança é sempre o servidor, nunca uma heurística local.

A adição de repositório Helm de cada role tinha o mesmo problema, só que pior: a checagem de mudança olhava uma string no stream de erro, mas o Helm imprime essa mensagem na saída padrão, então a task nunca via a string onde procurava e reportava mudança em toda execução, mesmo quando o repositório já estava lá.

| Sintoma antigo | Causa | Correção |
| --- | --- | --- |
| Repositório Helm sempre "changed" | Checagem lia stderr, mensagem sai em stdout | Trocada por checagem correta de stream |
| Kubeconfig do node sempre "changed" | Checksum do arquivo remoto nunca bate com o local já reescrito | Arquivo intermediário que nenhuma outra task reescreve |

O `spec.selector` de um Deployment, StatefulSet, DaemonSet ou Job é imutável no Kubernetes, e alguns charts upstream mudaram esse selector entre versões, o que faz o apply falhar contra um objeto instalado antes dessa mudança, mesmo forçando a resolução de conflito.

A role do ArgoCD trata isso: quando o apply falha, uma sub-rotina lê o erro do kubectl, que aparece em formatos de texto diferentes, com uma expressão regular aplicada ao stream de erro inteiro, não linha a linha, porque o texto de um mesmo conflito pode vir quebrado em mais de uma linha dependendo do formato, e casar linha por linha perderia objetos que o apply de fato travou.

A partir do que a extração encontra ali, a role identifica só os objetos travados, apaga cada um e reaplica o chart. É seguro porque o que é apagado é sempre o objeto de controle recriável pelo próprio chart, nunca dado; e é restrito ao objeto certo porque a extração lê o erro relatado pela API, não deleta nada às cegas.

Duas roles que também precisavam desse tratamento deixaram de existir: o mesmo tipo de conflito, se acontecer numa atualização de versão futura desses componentes, agora é responsabilidade do próprio Argo resolver, não mais de uma role Ansible.

Nas roles que primeiro copiam ou renderizam um arquivo para depois consumi-lo, a task que escreve esse arquivo é marcada para rodar de verdade mesmo em dry-run: sem isso, num node que ainda não tem o arquivo, ela não escreveria nada, correto para o próprio arquivo, que não é um recurso do cluster, e a task seguinte quebraria tentando ler um arquivo inexistente.

O limite de segurança do dry-run é sempre o modo de simulação do próprio apply contra o servidor, nunca a ausência de um arquivo temporário local.

Escrever esse arquivo de verdade sob dry-run não quebra a promessa do modo, porque o arquivo não é o estado que interessa: ele existe só para alimentar o comando seguinte, e o que decide se algo muda no cluster continua sendo o servidor. Confundir as duas coisas é o erro que faria um dry-run passar limpo por não conseguir nem chegar à comparação.

## Hardening de sistema operacional

As roles que vêm antes do k3s não instalam nada de Kubernetes; elas preparam o sistema operacional. O ponto de partida é uma imagem do Raspberry Pi OS pensada para uso de mesa, que traz serviços de desktop ligados, o `/tmp` sem restrição de montagem e o AppArmor compilado mas desativado.

Boa parte dessas roles, portanto, não está adicionando proteção nova e sim desfazendo padrões que ninguém escolheu para um node de servidor. Duas delas vão além e reconciliam de fato, o firewall e o hardening de SSH: o que não está declarado e aparece no node é removido, em vez de tolerado.

A role de pré-requisitos do sistema instala pacotes base e ajusta os parâmetros de cgroup que o k3s e o containerd exigem, reiniciando o node quando a linha de comando do kernel muda.

| O que a role de pré-requisitos faz | Por quê |
| --- | --- |
| Para e mascara o `rpcbind` | A imagem deixa escutando em toda interface sem uso; só depois de confirmar que não há montagem NFS |
| Desliga serviços de desktop não usados (avahi, bluetooth, cups, e outros) | Servidor não precisa deles |
| Bloqueia o rádio Wi-Fi | Node depende só do cabo; rádio ligado sem uso é superfície de ataque |
| Monta `/tmp` com `noexec`, `nosuid`, `nodev` | A imagem não traz essa restrição por padrão |
| Configura o `smartmontools` para o SSD via ponte USB | Precisa do tipo de dispositivo correto pra responder ao SMART |
| Compara pacotes manuais com uma baseline | Só avisa quando algo foi instalado à mão fora da lista, sem falhar |

A role de firewall instala e liga o firewalld, mantém SSH permitido na zona pública, confia os CIDRs internos de pod e serviço que o Cilium vai usar, deixa a porta da API do k3s fechada para toda rede, porque o `kubectl` roda no próprio node por SSH, e se recusa a recarregar uma configuração permanente que não contenha SSH: um erro nas regras nunca tranca o operador para fora.

A role também reconcilia: lê o que está gravado nas zonas pública e confiável, compara com o que os valores padrão declaram e remove o resto. Foi assim que apareceu uma porta da API aberta para qualquer origem na zona pública, que anulava a restrição por CIDR que existia à época; hoje a API não tem regra nenhuma, e a reconciliação remove qualquer uma que apareça.

A remoção tem um teto por execução: uma diferença maior aborta a role antes de tocar em qualquer coisa, porque quase sempre significa um erro de declaração, e não lixo acumulado.

A mesma role é a única dona do firewalld, então é ela, e não a role da tailnet, que declara a zona correspondente para a interface da tailnet, com os serviços de acesso liberados nela reconciliados como os da zona pública; as portas HTTP são do [ingress](ingress.md), que escuta direto no node, e ficam fechadas na zona pública.

Ela também apaga qualquer policy de encaminhamento entre zonas que alguém tenha declarado no node, as declaradas pelo operador, não as embutidas do firewalld, que não podem ser apagadas: o node não roteia nada entre a tailnet e a rede local, e uma policy que sobrou de uma versão anterior, que fazia dele um subnet router, seria exatamente o tipo de estado não declarado que a reconciliação existe para remover.

A distinção entre policy declarada e embutida importa aqui porque tentar apagar uma embutida falharia e derrubaria a role sem motivo. O que se quer remover é sempre o que alguém criou, e só isso.

A role da tailnet vem logo depois e liga o node à tailnet, sem anunciar rota nenhuma: instala o cliente pelo repositório apt oficial, com a chave de assinatura conferida contra um checksum fixado, e o `dnsmasq`; se o node ainda não está na tailnet e a chave de autenticação ainda é o valor de exemplo, ela avisa e pula o resto sem falhar, para que o bootstrap continue verde até a credencial existir.

Com a chave, ela escreve o valor num arquivo em tmpfs com modo 600 e sobe a conexão lendo o arquivo, para o segredo nunca aparecer na lista de processos, e apaga o arquivo mesmo se o comando falhar. Num node já ligado, a role reaplica as preferências declaradas, hostname e desligar aceitação automática de DNS e de rotas, e só reporta mudança quando as preferências de antes e de depois diferem.

O `dnsmasq` é configurado em camadas: a de escuta entra sempre, mesmo antes do node estar na tailnet, e o prende à interface da tailnet sem upstream, porque o pacote da Debian sobe por padrão escutando em toda interface e encaminhando pro resolvedor do sistema, um estado que ninguém declarou; a zona interna, respondida com o endereço do node na tailnet, só entra depois do login, quando esse endereço existe.

Uma consulta por qualquer outro nome recebe recusa em vez de virar um resolver aberto; um drop-in do systemd faz esse serviço subir depois do cliente da tailnet, e uma opção de bind dinâmico cobre o caso em que a interface aparece depois.

A separação em duas camadas existe porque as duas dependem de coisas diferentes: prender o processo à interface certa é seguro de fazer desde a instalação, enquanto responder pela zona exige um endereço que só existe depois do login na tailnet. Se as duas entrassem juntas, o bootstrap de um node ainda sem credencial ficaria com um `dnsmasq` no estado padrão do pacote, escutando em toda interface, que é justamente o que se quer evitar.

A role de atualizações automáticas liga atualizações de segurança com reboot automático numa hora fixa: se uma atualização instalada exigir reboot, o node reinicia sozinho àquela hora, fora de qualquer execução do Ansible. É o único reboot deste repositório que nenhuma role dispara nem espera.

O horário coincide com o do timer semanal de manutenção, descrito adiante, que roda aos domingos de madrugada com atraso aleatório; não há indício de que choquem de verdade, só a coincidência de janela vale ter em mente.

A role de hardening de sysctl aplica parâmetros de kernel recomendados, verificando primeiro se cada parâmetro existe no kernel do host antes de tentar defini-lo, e configura o kernel para reiniciar sozinho depois de um oops em vez de ficar travado.

A lista inclui parâmetros que escondem endereços do kernel e o log de kernel de usuários sem privilégio, e desliga redirects e source route em IPv4 e IPv6; o repasse de pacotes fica de fora porque o roteamento dos pods depende dele.

Os valores vão para um arquivo próprio em `/etc/sysctl.d/`, e não para o arquivo tradicional: a Debian 13 deixou de ler esse arquivo no boot, e foi assim que um reboot devolveu um desses parâmetros a zero e derrubou o Traefik, que não conseguia mais abrir a porta 80; o valor vivo estava certo e o arquivo também, só o boot não os ligava.

A mesma role baixa a porta mínima não privilegiada para 80, no sentido contrário do hardening: o Traefik do [ingress](ingress.md) roda no namespace de rede do host, sem root e sem capability, e sem isso não conseguiria escutar nas portas 80 e 443. O sysctl é por namespace de rede, então só alcança processos do host; os pods comuns já recebem o valor zero do kubelet no próprio namespace.

A role de umask declara uma máscara mais restritiva no arquivo de configuração de login, restringindo a permissão padrão de todo arquivo novo criado por um shell de login interativo; a ressalva é que isso não alcança um serviço gerenciado pelo systemd, como o próprio k3s, o containerd ou o agente do Cilium, cada um com seu próprio umask de processo.

A role é uma linha nesse arquivo e nada mais, o que deixa claro o alcance dela: o que um operador cria digitando num shell, não o que um daemon escreve. Para os arquivos que de fato guardam segredo, a permissão vem declarada na própria task que os escreve, como o modo 600 do kubeconfig e da configuração do k3s, e não desta role.

A role de AppArmor garante o pacote instalado e liga o módulo na linha de comando do kernel, reiniciando o node quando isso muda, no mesmo padrão da role de pré-requisitos para o cgroup de memória: o kernel da Raspberry Pi Foundation vem com o AppArmor compilado, mas não o ativa por padrão como uma Debian ou Ubuntu comuns ativariam, então assumir que "o Raspberry Pi OS já vem com isso" seria falso aqui.

A role não define nenhum perfil próprio, só garante que o controle de acesso obrigatório exista para ser usado depois. Ligar o módulo na linha de comando não basta como verificação, porque o arquivo editado pode nem ser o que o boot usa, então a role termina lendo o parâmetro vivo do módulo no kernel e falha se ele não responder que está ativo.

Essa checagem contra o estado vivo, e não contra o arquivo que ela mesma escreveu, é o que distingue ter declarado a intenção de ter o controle funcionando.

A role de auditoria liga auditoria de chamadas de sistema e vigia as mudanças que indicariam um invasor se instalando: arquivos de identidade, configuração do SSH e do firewalld, cron, carga e remoção de módulos do kernel, pelos binários e pelas syscalls, e a configuração e as credenciais do k3s. Cada regra leva uma chave própria, que é por onde se busca depois: sem elas, o registro do auditd é volume demais para ser lido.

Vigiar módulo do kernel pelos binários e pelas syscalls ao mesmo tempo é redundância deliberada, porque quem carrega um módulo por chamada direta não passa pelas ferramentas usuais. O que o auditd não faz é impedir qualquer uma dessas mudanças; ele registra, e o valor está em haver rastro quando algo já aconteceu.

A role de hardening de SSH trata a lista de chaves autorizadas como estado declarado: a lista vive num arquivo de variáveis de grupo, commitada em texto claro porque chave pública não é segredo, e a role reconcilia o node contra ela, removendo o que não está declarado, com o mesmo padrão de teto do firewall.

Antes de escrever qualquer coisa, ela extrai a chave pública correspondente à chave privada que o próprio Ansible está usando nesta conexão e confere que ela está na lista declarada; se não estiver, aborta sem tocar no arquivo, porque aplicar a mudança trancaria o operador para fora.

Essa extração roda sobre uma cópia temporária da chave privada, com permissão restrita e apagada no fim, delegada à máquina do operador: a ferramenta de extração recusa ler a chave original quando ela está com permissão mais aberta que o esperado, e a role não corrige isso na chave de verdade, só numa cópia descartável.

Só depois disso ela desliga login por senha e restringe o login root a autenticação por chave. O drop-in também limita o login a um grupo específico, reduz a janela de autenticação e liga um nível de log mais verboso, que registra a impressão digital da chave usada em cada login.

Antes de gravar, uma validação testa o drop-in novo junto com a configuração inteira do SSH, então uma configuração inválida nunca chega ao disco para derrubar o SSH no próximo reload. Do lado do operador, a configuração de conexão liga checagem estrita de host contra o arquivo local de hosts conhecidos, então o Ansible recusa conectar se a host key do Pi mudar.

Ela não instala chave nenhuma: a chave que importa é a que o Ansible já usou para entrar.

A role de fail2ban bane automaticamente origens com tentativas repetidas de login SSH inválido, com o banimento entrando por um ipset que o firewalld administra, a mesma peça que a role de firewall já governa, em vez do banaction clássico que mexe direto no iptables, e lendo o journal do systemd como backend, porque essa imagem não popula um arquivo de log tradicional; a escolha casa com o resto do repositório, que não tem rsyslog dedicado nenhum.

A jail banda cinco tentativas em dez minutos por uma hora, números modestos de propósito: com login por senha desligado pelo hardening de SSH, o fail2ban não é o que impede uma invasão por força bruta, e sim o que tira do journal o ruído constante de varredura.

O ban também vive num ipset, e não como regra de zona, então ele fica fora do que a role de firewall reconcilia: um endereço banido não aparece para ela como configuração não declarada a remover.

## Plataforma Kubernetes

A role do k3s baixa o binário da release oficial no GitHub para a arquitetura do node e o verifica contra o arquivo de checksum publicado na mesma release antes de qualquer outra coisa; só então roda o instalador oficial pedindo pra pular o download, para que o script configure o serviço mas nunca baixe um binário por conta própria.

O instalador em si é baixado da tag do k3s no GitHub, não do domínio de instalação genérico, e conferido contra um checksum fixado nas variáveis de versão, porque um script executado como root não pode ser o único download do bootstrap sem checksum; como o `/tmp` está montado sem permissão de execução, a role o chama explicitamente pelo interpretador em vez de executá-lo direto.

São dois downloads conferidos por dois motivos diferentes: o binário porque é o que vai rodar como servidor da API, e o script porque roda como root uma única vez e pode fazer qualquer coisa nesse intervalo.

A conferência de cada um vem de uma fonte diferente por consequência disso: o binário é comparado com o arquivo de checksum da própria release, que acompanha a versão automaticamente, enquanto o script tem o seu digest escrito nas variáveis de versão, para que uma mudança nele apareça no diff de um pull request.

O k3s sobe com o backend de rede padrão e o kube-proxy embutido desabilitados via configuração declarativa, porque o Cilium assume essas responsabilidades a seguir, e com os addons de ingress, balanceador e armazenamento local desligados na mesma configuração, porque cada um deles é substituído por algo que o repositório declara e pina: o [ingress](ingress.md), nenhum balanceador, e o provisioner de volumes do app de armazenamento, descrito em [GitOps: root e satélites](gitops-root-e-satelites.md).

Um addon que o k3s embute reaplica o próprio manifesto a cada reinício, então não dá para só editar o objeto dele no cluster.

Quando essa configuração muda num node já instalado, a role reinicia o node e espera por ele com uma janela alongada: um Raspberry Pi com o k3s e muitos contêineres leva vários minutos só para desligar, e a janela padrão do módulo de reboot já foi curta o bastante para o Ansible declarar o node inalcançável enquanto ele ainda estava reiniciando normalmente.

A mesma configuração declara uma política de auditoria do API server que registra metadados de toda escrita, o corpo completo de mudanças em RBAC, projetos do Argo e execução em pods, metadados de todo acesso a `SopsSecret`, e nada de leitura de rotina.

| Configuração no `config.yaml` do k3s | Efeito |
| --- | --- |
| `secrets-encryption: true` | Todo `Secret` nasce cifrado em repouso; sem passo de recifragem |
| `token` | Token de join, cifrado no repositório, gravado com modo 600 |

A role lê o status de cifragem depois do API server responder e aborta se ela não estiver ativa; como a opção entra na configuração antes do primeiro start, não existe passo de recifragem retroativa. É para o valor declarado do token que a rotação converge um node já vivo. A chave de cifragem fica só no node, num diretório do próprio k3s.

O mesmo padrão de checksum publicado vale para o Helm e o cliente do Cilium, que a role do Cilium instala: o hash não fica no repositório porque o Renovate não teria como atualizá-lo junto com a versão, mas a integridade do download é verificada contra o que o próprio projeto publica, por TLS, a cada instalação.

O que se perde em relação ao digest escrito no repositório é a revisão humana: uma versão republicada com conteúdo diferente passaria, porque o checksum publicado mudaria junto com ela. As duas tasks também só baixam quando o binário ainda não está instalado, então um bootstrap repetido não volta à rede por causa delas.

A role do Cilium verifica que o k3s já desabilitou o que precisa, então instala o Cilium via chart Helm oficial, com aplicação de política sempre ativa e modo de auditoria desligado.

As políticas de rede de cada namespace do sistema já existem, e o tráfego que faltava foi observado pelo Hubble por um período com o modo de auditoria ligado antes de desligá-lo, então o enforcement agora bloqueia de verdade o que não está explicitamente permitido, com o Hubble ligado para observabilidade.

O agente fala com o API server pelo endereço local, não pelo endereço do inventário, liga a interface web do Hubble, servida pelo ingress, e se prende a um padrão de interface de rede em vez de a uma interface fixa: o node trocou de Wi-Fi para cabo e mudou de rede, e com a interface e o IP antigo gravados no chart nenhum pod voltava a subir depois do reboot.

O chart sobe com roteamento em modo túnel via VXLAN, em vez de roteamento nativo, porque VXLAN não depende de rota L3 direta entre nodes: só importa hoje se um segundo node algum dia entrar numa sub-rede L2 diferente da deste, mas evita ter que revisitar essa decisão nesse momento.

O proxy de camada 7 embutido fica desligado, o que economiza CPU e memória num Raspberry Pi de nó só, ao custo de não dar pra escrever uma política de rede que filtre por método ou caminho HTTP, só por porta e protocolo de transporte.

Os certificados do Hubble usam um Job agendado como método de emissão, e não o padrão baseado em release do Helm: sem um release de Helm de verdade guardando estado, a função de busca que o chart usaria para reaproveitar a CA já existente sempre volta vazia dentro de uma renderização sem cluster, e o método padrão regeneraria a CA e os certificados a cada reaplicação; veja [Helm e os charts](helm-e-charts.md).

O agente, o operator e o Hubble Relay têm pedido e limite de memória declarados, sem limite de CPU, para não estrangular o agente num node de um nó só.

Quando a sonda encontra diferença de verdade e reinicia o DaemonSet do agente e a implantação do Hubble Relay juntos, o Relay costuma sofrer turbulência transitória antes de estabilizar sozinho; o comando de status do Cilium espera por várias tentativas antes de desistir, em vez de confiar só no timeout interno padrão.

O Cilium ainda cifra o tráfego entre pods com WireGuard, cujo módulo já vem no kernel do node; num nó só isso quase não muda nada, porque os pacotes não saem da máquina, mas deixa um segundo node pronto para entrar sem tráfego em claro no Wi-Fi.

A role do ArgoCD instala o ArgoCD, com o modo inseguro ligado nos values porque o TLS do domínio interno é terminado pelo [ingress](ingress.md) e o servidor só precisa servir HTTP por dentro, com o login pelo realm `management` do Keycloak, com PKCE, que o client do realm exige; o client secret vem de um segredo cifrado, entregue pela aplicação de login único.

| Configuração do ArgoCD | Valor |
| --- | --- |
| `admin.enabled` | Falso; emergência é `kubectl` no node, já com acesso total |
| RBAC | Só o grupo de administradores tem papel |

A mesma configuração registra o segredo compartilhado do webhook do GitHub. O segredo é comparado com o que já está no cluster a cada execução e reaplicado só quando difere, então uma rotação no arquivo de segredos chega ao cluster no bootstrap seguinte; essas tasks rodam sem log, porque a leitura devolve o valor atual codificado em base64.

A configuração do chart vive num arquivo próprio, copiado para o node antes da renderização: métricas, pedido e limite de memória em cada componente, imagens do ArgoCD e do dex pinadas por [digest](../aprender/pinagem-por-digest-e-hash.md), o Renovate mantém o digest junto da tag, e o redis com identidade própria, sem token da API montado.

O pedido e limite de memória do application controller foi elevado depois de o pod ser morto por falta de memória repetidas vezes ao reconciliar todas as aplicações de uma vez, cada reinício custando um pico de CPU no node inteiro.

O redis também vai por digest, resolvido direto no mirror de onde o chart o puxa, porque o digest que importa é o da imagem que o node de fato baixa. Pinar por digest e não só por tag tira do caminho a possibilidade de a mesma tag apontar para outra imagem entre uma instalação e a seguinte, que é o equivalente, no registry, da versão de chart republicada.

O custo é que cada bump passa a mexer em duas linhas em vez de uma, e é por isso que o digest fica junto da tag, onde o Renovate consegue atualizar os dois de uma vez.

Como o namespace do ArgoCD nasce dessa role, e não de uma aplicação com criação automática de namespace, é ela quem aplica os labels de Pod Security restrito nesse namespace; os outros namespaces recebem os mesmos labels pelo próprio Argo.

Essa é a única exceção a uma regra que vale para o resto do cluster, e ela existe só porque o ArgoCD precisa de um namespace antes de existir para criar namespaces. Como a exceção é fácil de esquecer numa mudança futura, o gate de segurança de Pod exige que todo namespace criado por uma aplicação declare o nível de enforce, e trata o namespace do ArgoCD como caso conhecido justamente por reconhecer a task desta role.

## A ponte para o GitOps

A role de bootstrap da aplicação aplica manualmente uma aplicação do Argo: a aplicação root, descrita em [GitOps: root e satélites](gitops-root-e-satelites.md), e os projetos declarados junto dela. A URL do repositório que o root sincroniza vem de uma variável própria, cujo padrão é este repositório.

Um fork ou um ambiente de teste pode sobrescrever essa variável no arquivo de segredos para o primeiro bootstrap, mas precisa também trocar a URL nos manifestos correspondentes: depois que o root existe, ele passa a sincronizar os projetos a partir do git, e a lista de repositórios de origem voltaria para a URL commitada. Da primeira execução em diante, a role só reaplica o que o root não gerencia, o manifesto do próprio root.

A partir do momento em que o root existe no cluster, tudo o que acontece depois é responsabilidade do Argo, não do Ansible: é assim que o cert-manager, o CNPG, o sops-secrets-operator e o Kargo chegam ao cluster hoje, como aplicações de plataforma sincronizadas pelo root, sem role própria.

Só o Cilium e o próprio ArgoCD continuam instalados pelo Ansible, permanentemente: são pré-requisitos de bootstrap que precisam existir antes de qualquer coisa GitOps poder funcionar, e não podem se autogerenciar antes de existir.

A consequência prática dessa fronteira é que subir a versão do cert-manager ou do Kargo é um merge, enquanto subir a do Cilium ou do próprio Argo exige rodar o bootstrap contra o node. Vale a pena ter em mente qual dos dois lados uma mudança toca antes de abrir o pull request, porque o caminho até o cluster é diferente.

A role da chave age garante o binário instalado e, se o segredo correspondente ainda não existir no namespace `sops`, gera um par de chaves novo num diretório temporário, cria o segredo a partir dele e apaga o diretório logo em seguida, num bloco que roda mesmo se um passo no meio falhar.

Diferente do segredo do webhook do Argo, essa chave não vem do arquivo de segredos do repositório: ela nasce no próprio node, nunca fica num arquivo permanente nele, e nem a máquina do operador nem este repositório chegam a ver a metade privada em nenhum momento.

A checagem de existência desse segredo é o que torna a role segura de rodar de novo: gerar uma chave nova por engano tornaria todo `SopsSecret` já commitado indecifrável.

A role roda logo depois do Cilium e antes do ArgoCD, de propósito: a aplicação do sops-secrets-operator, uma das aplicações de plataforma que o root sincroniza, monta esse segredo assim que ele existe, e rodar a role depois do ArgoCD a deixaria tentando montar um segredo ainda inexistente na primeira sincronização.

A metade pública é lida de volta do segredo, nunca do diretório temporário, que já não existe nesse ponto, e impressa na tela em toda execução do bootstrap, não só na primeira; a receita de sincronizar destinatários escreve ela direto no arquivo de configuração do SOPS, sem depender de ter visto esse output.

As receitas de adicionar, atualizar e remover cuidam dos demais destinatários, a chave de rotina do operador, a de desastre, qualquer outra, que não têm papel fixo nem quantidade fixa.

A separação entre os comandos existe porque o destinatário do node é o único que o repositório sabe derivar sozinho, lendo o cluster; os demais dependem de alguém dizer qual chave entra ou sai. Imprimir a metade pública em toda execução, e não só na primeira, é o que permite reconstruir o arquivo de configuração sem depender de ter guardado o output do dia do bootstrap.

## Manutenção contínua

O host é reconciliado pela recipe de bootstrap rodada pelo operador, e não por um `ansible-pull` agendado no próprio node. A decisão foi deliberada: essa alternativa exigiria deixar no node uma chave de leitura do repositório e o arquivo de segredos, que hoje só existe na máquina do operador, e várias roles reiniciam o node ou o k3s, o que não deveria acontecer sem alguém olhando.

A deriva que um pull agendado pegaria é coberta de outro jeito: o dry-run antes de cada mudança, o relatório de pacotes instalados à mão e a reconciliação do firewall.

Um bootstrap sem nada a mudar ainda leva alguns minutos, e a maior parte desse tempo não é o Ansible comparando estado, é o node fazendo trabalho repetido. Várias medidas cortam isso sem tirar nada do que é reconciliado.

| Otimização | Efeito |
| --- | --- |
| Tag por role no `site.yml` | Roda ou pula só o trecho mexido, sem reordenar nada |
| `cache_valid_time` no `apt` | Índice atualiza só de tempos em tempos, não a cada role |
| `pipelining` no `ansible.cfg` | Cada módulo executa numa única conexão SSH |
| Cache de facts local | Evita reler fatos do node em toda execução |
| Callback de profiling | Mede as tasks mais demoradas, guiando a próxima otimização por dado |

A que mais pesa é o atalho por hash. As roles do Cilium e do ArgoCD renderizam o chart e o comparam com o cluster a cada execução, depois de atualizar o repositório Helm; no Raspberry Pi isso custa um tempo real por chart, mesmo quando nada mudou.

Agora cada uma calcula um hash das suas entradas, a versão do chart e o conteúdo dos values renderizados, e o compara com o hash gravado pela última execução que confirmou o cluster igual ao declarado; se bater, a role pula a atualização do repositório, o diff e o apply, e diz isso na saída.

O hash só é gravado quando o diff devolve vazio ou o apply termina bem, então uma execução interrompida no meio refaz a comparação na próxima.

O que o atalho não vê é deriva feita por fora, alguém que rodou `kubectl` direto no cluster sem mudar o git; uma variável de execução força o diff contra o cluster em ambas as roles, e vale rodar assim depois de qualquer intervenção manual ou na revisão periódica.

A task que garante o diretório de charts existente roda de verdade mesmo em dry-run em ambas as roles, porque o download do chart pinado por digest também precisa acontecer de verdade nesse modo, para conferir o digest contra o declarado: sem isso, um dry-run que primeiro encontra o atalho de hash já satisfeito simula a criação do diretório em vez de criá-lo, e o download seguinte falha tentando escrever nele.

É o mesmo raciocínio do arquivo renderizado antes do apply: o que precisa ser real sob dry-run é o preparo que alimenta a comparação, nunca a comparação em si. O detalhe só aparece quando o atalho por hash não dispara, o que faz dele um caso fácil de quebrar sem perceber numa mudança futura.

A role de manutenção deixa agendado no node: journal persistente em disco, a imagem do Raspberry Pi OS o deixa só em memória, com teto de tamanho, piso de espaço livre e prazo de retenção declarados na própria role, e um timer semanal de madrugada que apaga ReplicaSets com zero réplicas, remove imagens de contêiner sem uso e imprime o espaço em disco.

É o que impede um node de um nó só de encher o disco com o rastro de meses de deploys. O serviço do timer roda com sandbox do systemd, sistema de arquivos protegido, sem novos privilégios, `/tmp` privado e escrita só nos diretórios de que o script precisa.

A role do kube-bench roda depois dela e instala o kube-bench direto no host, a partir do tarball da release conferido por checksum, com um timer semanal de segunda de manhã que grava o resultado em JSON.

As checagens de master, etcd, control plane e node do perfil do k3s precisam ler os argumentos do processo do k3s, os arquivos do próprio Rancher e o journal do systemd, e nada disso existe dentro de um pod sem root; por isso o CronJob do cluster ficou só com as checagens de política, e o host cobre o resto.

O serviço roda como root, porque precisa ler esses arquivos, mas com sistema de arquivos protegido e escrita só no diretório do relatório. O alerta a partir do relatório espera o webhook do Discord.

## Continue por aqui

Para ver por que algumas dessas roles instalam via chart Helm em vez de manifesto vendorizado, veja [Helm e os charts](helm-e-charts.md). Para as rotinas que ficam fora de `site.yml` de propósito, veja [rotacionar credenciais](../operacional/rotacionar-credenciais.md).
