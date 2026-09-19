# Tailscale: acesso remoto e DNS interno

<!-- source-of-trust paths="ansible/roles/tailscale ansible/group_vars/all/tailscale.yml tofu/tailscale" -->

O blog é público, mas tudo o mais que roda no node (o Argo CD, o Grafana, o console do Keycloak, o SSH) só deveria ser alcançável por quem opera o cluster. Até aqui isso significava estar na mesma rede local.

A tailnet resolve o problema sem abrir porta nenhuma na internet: o node entra numa rede privada do Tailscale, e cada dispositivo do operador que também entra passa a alcançá-lo por um endereço estável, com tráfego cifrado fim a fim e autenticação por identidade, de qualquer lugar. Esta página descreve o que o repositório declara para isso e onde termina a parte declarada.

## O que fica de cada lado

Cada peça mora numa ferramenta diferente, e cada uma só faz o que a outra não consegue. O Ansible é o único que entra no sistema operacional do node, então pacote instalado, serviço ligado e porta liberada no firewalld nascem dele.

O OpenTofu é o único que fala com a API da conta do Tailscale, onde vive o split DNS, e por isso depende de o node já estar na tailnet para descobrir o endereço dele. O Argo CD não alcança nenhum dos dois lados e só cuida do que responde depois que o nome resolve.

O Ansible, pela role do Tailscale, instala o cliente e o resolvedor local no node pelo apt e liga o node à tailnet; a role de firewall abre a zona da tailnet, com SSH, DNS e as portas HTTP do ingress.

A chave do repositório apt do Tailscale é conferida contra o SHA-256 declarado em `tailscale_apt_key_sha256`, nos defaults da role, e o índice do apt é reaproveitado quando outra role já o atualizou na última hora, em vez de atualizado de novo. Isso é estado do host, e o host é território do Ansible, como o k3s e o firewalld.

A descrição task a task está em [Ansible: as roles do bootstrap](ansible.md).

O OpenTofu, pelo módulo `tofu/tailscale`, declara o lado que vive na conta do Tailscale: o split DNS que manda toda consulta pelo domínio interno para o endereço do node na tailnet. Ele não declara o search path da tailnet, de propósito: é uma lista única para a tailnet inteira, e gerenciá-la daqui substituiria os search paths que o operador já tem para outros domínios.

Ele lê o endereço do node com o data source `tailscale_device`, então só roda depois que o Ansible ligou o node; a ordem está no [primeiro bootstrap](../operacional/primeiro-bootstrap.md). O módulo divide com o da Cloudflare a passphrase do state e o mesmo fluxo de credenciais por `sops exec-env`, descrito em [OpenTofu](opentofu.md).

Registrar uma chave nova no arquivo de destinatários, como a chave de desastre, recifra o arquivo de segredos do módulo para o destinatário novo sem tocar no que o módulo lê dali, as três variáveis da tabela abaixo.

| Variável |
| --- |
| `TAILSCALE_OAUTH_CLIENT_ID` |
| `TAILSCALE_OAUTH_CLIENT_SECRET` |
| `TAILSCALE_TAILNET` |

O Argo CD entra só no passo seguinte. O DNS interno é um serviço do host, não do cluster, porque o cluster não tem como oferecer a porta 53 no endereço da tailnet sem um encaminhamento pelo firewalld que passaria por fora do que o Cilium controla.

O que o Argo CD declara é o que vem depois de o nome resolver: o [ingress](ingress.md), um Traefik escutando no node pelas portas 80 e 443, que roteia cada nome interno para o Service certo, com certificados de uma CA interna. A zona da tailnet no firewall libera HTTP e HTTPS para ele, e nada além disso.

## Como uma consulta chega ao node

Um dispositivo da tailnet pergunta por `grafana.guesant.internal`. O cliente Tailscale nele vê que o domínio tem split DNS configurado e manda a consulta para o servidor de nomes declarado, que é o endereço do node na tailnet.

No node, o resolvedor local escuta só na interface da tailnet desde a instalação, antes mesmo de o node entrar na tailnet, responde qualquer nome sob o domínio interno com o próprio endereço do node assim que esse endereço existe, e recusa qualquer outro nome, porque não tem upstream configurado. A zona é um curinga (`address=/guesant.internal/...`), então um serviço novo não precisa de registro DNS: precisa só de uma regra no ingress.

Nada disso vale fora da tailnet: na rede local ou na internet, o domínio interno não existe, e a porta 53 do node não está aberta em nenhuma outra interface.

## Por que o node não é subnet router

O Tailscale permite que um node anuncie a rede local inteira para a tailnet, e o Raspberry Pi poderia fazer isso. A decisão foi não fazer: o que interessa alcançar de fora são os serviços que o próprio node hospeda, e para isso basta o node ser um destino na tailnet, com SSH, DNS e o ingress.

Anunciar a rede local exporia o roteador e qualquer outro dispositivo da casa a quem entrasse na tailnet, sem que nenhum deles fosse o motivo do acesso, e traria junto encaminhamento, masquerade e uma aprovação de rota no console para manter. Por isso a role do Tailscale não anuncia rota, a role de firewall apaga qualquer policy de encaminhamento que encontre no node, e `--accept-routes=false` também impede o node de aprender rotas anunciadas por outros dispositivos.

Os CIDRs do cluster seguem o mesmo raciocínio: alcançar um Service por dentro passaria por fora das políticas de rede do Cilium e do ingress, que é onde o acesso a cada serviço deve ser decidido.

## O que continua fora do git

A tailnet tem estado que o repositório não declara, e [estado fora do git](../operacional/estado-fora-do-git.md) lista cada item: a chave de autorização com que o node entra (cifrada em `secrets.sops.yaml`, mas criada no console), o OAuth client que o OpenTofu usa (cifrado em `tofu/tailscale/tailscale.sops.env`, criado no console), e a desativação da expiração da chave do node, que é um clique no console de administração.

A política de acesso da tailnet (a ACL) também fica fora, deliberadamente: o provider consegue gerenciá-la, mas ele substitui o documento inteiro, e a tailnet do operador tem outros dispositivos e regras que este repositório não conhece. Quando a ACL passar a ser gerenciada, uma `tag:homelab` para o node é a primeira coisa a declarar.

## Continue por aqui

O [modelo de ameaças](modelo-de-ameacas.md) descreve o que muda quando a tailnet vira uma fronteira de confiança. Para o passo a passo de criar as credenciais e ligar o node, veja o [primeiro bootstrap](../operacional/primeiro-bootstrap.md).
