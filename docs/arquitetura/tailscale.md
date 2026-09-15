# Tailscale: acesso remoto e DNS interno

<!-- source-of-trust paths="ansible/roles/tailscale ansible/group_vars/all/tailscale.yml tofu/tailscale" -->

O blog é público, mas tudo o mais que roda no node (o Argo CD, o Grafana, o console do Keycloak, o SSH) só deveria ser alcançável por quem opera o cluster. Até aqui isso significava estar na mesma rede local. A tailnet resolve o problema sem abrir porta nenhuma na internet: o node entra numa rede privada do Tailscale, e cada dispositivo do operador que também entra passa a alcançá-lo por um endereço estável, com tráfego cifrado fim a fim e autenticação por identidade, de qualquer lugar. Esta página descreve o que o repositório declara para isso e onde termina a parte declarada.

## O que fica de cada lado

Três peças, em três ferramentas, e cada uma só faz o que a outra não consegue.

O Ansible, pela role `tailscale`, instala o cliente e o `dnsmasq` no node, liga o node à tailnet e anuncia as rotas declaradas; a role `firewall` abre a zona `tailscale`, a policy de encaminhamento e o masquerade. Isso é estado do host, e o host é território do Ansible, como o k3s e o firewalld. A descrição task a task está em [Ansible: as roles do bootstrap](ansible.md).

O OpenTofu, pelo módulo `tofu/tailscale`, declara o lado que vive na conta do Tailscale: o split DNS que manda toda consulta por `guesant.internal` para o endereço do node na tailnet, e o search path que permite digitar só o nome curto. Ele lê o endereço do node com o data source `tailscale_device`, então só roda depois que o Ansible ligou o node; a ordem está no [primeiro bootstrap](../operacional/primeiro-bootstrap.md). O módulo divide com o da Cloudflare a passphrase do state e o mesmo fluxo de credenciais por `sops exec-env`, descrito em [OpenTofu](opentofu.md).

O Argo CD não entra nesta camada, de propósito. O DNS interno é um serviço do host, não do cluster, porque o cluster não tem como oferecer a porta 53 no endereço da tailnet sem um `hostNetwork` ou um encaminhamento pelo firewalld que passaria por fora do que o Cilium controla. O que o Argo CD vai declarar é o passo seguinte: um ingress ouvindo em `tailscale0` que roteie `grafana.guesant.internal`, `argocd.guesant.internal` e os demais nomes para os `Service` certos. Sem ele, `*.guesant.internal` resolve para o node, mas o node ainda não sabe o que responder em HTTP.

## Como uma consulta chega ao node

Um dispositivo da tailnet pergunta por `grafana.guesant.internal`. O cliente Tailscale nele vê que o domínio tem split DNS configurado e manda a consulta para o servidor de nomes declarado, que é o endereço do node na tailnet. No node, o `dnsmasq` escuta só em `tailscale0`, responde qualquer nome sob `guesant.internal` com o próprio endereço do node e recusa qualquer outro nome, porque não tem upstream configurado. A zona é um curinga (`address=/guesant.internal/...`), então um serviço novo não precisa de registro DNS: precisa só de uma regra no ingress. Nada disso vale fora da tailnet: na rede local ou na internet, `guesant.internal` não existe, e a porta 53 do node não está aberta em nenhuma outra interface.

## Como o node vira subnet router

`tailscale_advertise_routes` lista os CIDRs que o node anuncia para a tailnet. Com uma rota anunciada e aprovada, um dispositivo da tailnet que mande um pacote para um endereço dessa faixa o entrega ao node, que o encaminha para a rede local. Do lado do node, três coisas precisam existir para isso funcionar, e a role `firewall` declara as três: `ip_forward` ligado (já era, para os pods), a policy `tailscale-to-lan` aceitando o tráfego que entra por `tailscale0` e sai pela zona pública, e o masquerade das origens da tailnet, para o dispositivo da LAN responder ao node em vez de a um endereço `100.x` que ele não sabe rotear. Os CIDRs do cluster não são anunciados: alcançar um `Service` por dentro passaria por fora das políticas de rede do Cilium e do ingress, que é onde o acesso a cada serviço deve ser decidido.

## O que continua fora do git

A tailnet tem estado que o repositório não declara, e [estado fora do git](../operacional/estado-fora-do-git.md) lista cada item: a chave de autorização com que o node entra (cifrada em `secrets.sops.yaml`, mas criada no console), o OAuth client que o OpenTofu usa (cifrado em `tofu/tailscale/tailscale.sops.env`, criado no console), a aprovação da rota anunciada e a desativação da expiração da chave do node, que são cliques no console de administração. A política de acesso da tailnet (a ACL) também fica fora, deliberadamente: o provider consegue gerenciá-la, mas ele substitui o documento inteiro, e a tailnet do operador tem outros dispositivos e regras que este repositório não conhece. Quando a ACL passar a ser gerenciada, `autoApprovers` para as rotas e uma `tag:homelab` para o node são as duas primeiras coisas a declarar.

## Continue por aqui

O [modelo de ameaças](modelo-de-ameacas.md) descreve o que muda quando a tailnet vira uma fronteira de confiança. Para o passo a passo de criar as credenciais e ligar o node, veja o [primeiro bootstrap](../operacional/primeiro-bootstrap.md).
