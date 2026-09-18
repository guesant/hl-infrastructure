# Mapa do bootstrap e das credenciais

<!-- source-of-trust paths="tofu/*/secrets.map .sops.yaml .config/secret-max-age.conf ansible/site.yml" -->

Esta página responde, num lugar só, o que precisa existir para o node funcionar do zero, em que ordem, quem depende de quem, onde vive cada credencial e o que muda entre o primeiro bootstrap e a manutenção. Ela não substitui o passo a passo do [primeiro bootstrap](primeiro-bootstrap.md); ela explica o porquê de cada passo estar onde está, para que uma mudança futura seja feita no lugar certo. Vale lê-la antes de mover uma credencial de arquivo ou de acrescentar uma camada, porque boa parte das escolhas descritas aqui existe para que nada dependa de um estado que só vive na máquina de quem fez o bootstrap.

## As camadas, e a ordem entre elas

Tudo o que o repositório declara cabe em camadas bem definidas, e cada uma só faz sentido depois da anterior. A ordem não é uma escolha de apresentação: cada camada usa uma credencial e um caminho de rede que a anterior criou, e é por isso que pular uma delas numa restauração falha de forma barulhenta em vez de degradar em silêncio. Nenhuma camada reconcilia a de cima, tampouco: o Argo CD não conserta o node, e o Ansible só reconcilia a `Application` `root` e os `AppProject` dela, sem olhar para o que a `root` sincroniza depois.

A camada do host é o Raspberry Pi com Debian, SSH e um usuário com chave. Ela não está no repositório; é o único pré-requisito humano, descrito em [restaurar o node](restaurar-o-node.md). O que o repositório exige dela é pouco: um IP alcançável, um usuário que consegue `sudo` e a chave pública do operador já em `authorized_keys`, porque a role `ssh_hardening` reconcilia esse arquivo e recusa aplicar uma lista que não contenha a chave da própria conexão.

A camada do Ansible é `just bootstrap`, que transforma esse host num node: endurecimento do sistema, firewall com as zonas `public` e `tailscale`, o cliente Tailscale e o `dnsmasq` do DNS interno, o k3s com Cilium, o Argo CD e a `Application` `root`. É a única camada que roda com a identidade do operador e precisa do Touch ID, porque decifra `ansible/group_vars/all/secrets.sops.yaml` em memória para ler o token do k3s, o segredo do webhook e a chave da tailnet. Depois dela o node está inteiro, mas o cluster ainda está vazio de aplicações.

A camada do Argo CD, a partir da `root`, sincroniza tudo em `argocd/applications` sem ninguém rodar nada: operadores, políticas, monitoramento, ingress, Keycloak, Portainer, Dashy, oauth2-proxy e o blog. Os segredos dessa camada são `SopsSecret`, cifrados para a chave age do node, que o sops-secrets-operator decifra dentro do cluster; o operador não participa. É por isso que um push em `main` chega ao cluster sem Touch ID.

A camada dos serviços externos ao cluster é o que o OpenTofu declara: o túnel e o DNS na Cloudflare, o split DNS na tailnet. Eles rodam do Mac do operador, com Touch ID, e dependem da camada anterior só para o túnel ter para onde apontar; o DNS da tailnet depende de o node já estar nela (a camada do Ansible). O acesso aos provedores é sempre pelo mesmo caminho: `tofu-run.sh` decifra `tofu/state.sops.env` e o arquivo do próprio módulo em memória e entrega os valores ao contêiner do OpenTofu como variáveis de ambiente, nunca como arquivo montado. Se algum deles ainda guardar um `REPLACE_WITH_`, ele recusa rodar antes de falar com qualquer provider, o que transforma um arquivo pela metade em erro imediato em vez de num `apply` parcial.

A camada do Keycloak, também pelo OpenTofu, são os realms e tudo dentro deles. Ela depende de todas as anteriores, porque fala com o Keycloak pelo nome interno da tailnet (a camada do Ansible), que o ingress serve (a camada do Argo CD) com o certificado da CA interna (a camada do Argo CD), e porque os client secrets que ela aplica são os mesmos `SopsSecret` que os consumidores da camada do Argo CD montam. É a camada com mais pré-requisitos, e uma falha nela costuma aparecer como erro de TLS ou de nome não resolvido, e não como recurso faltando, porque o obstáculo está no caminho até o Keycloak e não no que o módulo declara.

## Quem depende de quem

Lendo de baixo para cima, com o que cada peça exige da anterior:

- `ansible/site.yml` exige o host com SSH e a identidade age do operador para decifrar `secrets.sops.yaml`. Nada mais.
- A `Application` `root` exige o Argo CD instalado pela role `argocd` e o repositório público no GitHub. O webhook do GitHub, cujo segredo a role grava em `argocd-secret`, só acelera; sem ele o Argo consulta o repositório no ciclo periódico normal.
- Todo `SopsSecret` exige o sops-secrets-operator com a chave privada do node, gerada pela role `sops_age_key` e registrada como destinatário em `.sops.yaml`. Um `SopsSecret` cifrado antes de a chave do node existir não abre; `just sops-sync` recifra tudo para os destinatários atuais.
- O ingress exige o cert-manager (a CA interna é um `ClusterIssuer`), a zona `tailscale` do firewall com `http` e `https`, e o sysctl que deixa o Traefik escutar em portas baixas sem root; todos vêm do Ansible.
- O login em qualquer serviço exige o Keycloak no ar (Argo), o realm aplicado (Tofu) e um usuário criado no console pelo `admin` do `master`, com e-mail e no grupo `admins`; não há provedor externo, e senha e TOTP vivem só no Keycloak.
- `tofu/tailscale` exige o node na tailnet, porque lê o endereço dele com um data source. `tofu/cloudflare` não exige nada do cluster para o `apply`, mas o túnel só carrega tráfego depois que o cloudflared do blog está rodando com o token que `just cloudflare-tunnel-token` grava no `SopsSecret`.
- `tofu/keycloak-master` exige o Keycloak alcançável por `keycloak.guesant.internal` e, num cluster vazio, o administrador de bootstrap que o `SopsSecret` `keycloak-bootstrap-admin` entrega ao pod, com a mesma credencial declarada no `keycloak-master.sops.env`. `tofu/keycloak-homelab` e `tofu/keycloak-management` exigem o `master` aplicado, porque autenticam com as contas de serviço que ele cria.

## Onde vive cada credencial

Toda credencial que o repositório conhece está cifrada com SOPS para os destinatários de `.sops.yaml`: a identidade da Secure Enclave do operador, a chave do node e a chave de desastre. O que muda de um arquivo para outro é quem o lê e quando. O conjunto de destinatários é declarado uma vez no topo de `.sops.yaml` e reaproveitado por todas as regras de caminho, então acrescentar ou trocar um destinatário é uma edição só, seguida de `just sops-sync` para recifrar o que já estava commitado. Um arquivo cifrado antes dessa edição continua legível apenas para os destinatários antigos até o sync passar por ele.

| Arquivo | Formato | Quem lê | Quando | Conteúdo (chaves, não valores) |
| --- | --- | --- | --- | --- |
| `ansible/group_vars/all/secrets.sops.yaml` | YAML | Ansible, pelo vars plugin `community.sops`, no Mac do operador | Todo `bootstrap`, `bootstrap-check` e playbook de rotação | `k3s_join_token`, `argocd_github_webhook_secret`, `tailscale_auth_key` |
| `tofu/state.sops.env` | dotenv | `tofu-run.sh`, para todo módulo | Todo `plan` e `apply` | `TF_VAR_state_passphrase`, que cifra os `terraform.tfstate` commitados |
| `tofu/cloudflare/cloudflare.sops.env` | dotenv | `tofu-run.sh`, só para `cloudflare` | `plan`, `apply`, `just cloudflare-tunnel-token` | API token e IDs de conta e zona |
| `tofu/tailscale/tailscale.sops.env` | dotenv | `tofu-run.sh`, só para `tailscale` | `plan` e `apply` | OAuth client da tailnet |
| `tofu/keycloak-master/keycloak-master.sops.env` | dotenv | `tofu-run.sh` para `keycloak-master`; os outros módulos leem dele as contas de serviço pelo `secrets.map` | `plan` e `apply` dos módulos do Keycloak | administrador atual e permanente do `master`, segredos de `tofu-homelab` e `tofu-management` |
| `argocd/apps/platform/sso/templates/*.sops-secret.yaml` | `SopsSecret` | sops-secrets-operator; `tofu/keycloak-management` | Sync; `plan` e `apply` do `management` | client secrets de `argocd` e `grafana` |
| `argocd/apps/platform/oauth2-proxy/templates/oauth2-proxy.sops-secret.yaml` | `SopsSecret` | sops-secrets-operator; `tofu/keycloak-management` | Sync; `plan` e `apply` do `management` | client secret do `oauth2-proxy` e segredo do cookie |
| `argocd/apps/platform/portainer/templates/portainer-oidc.sops-secret.yaml` | `SopsSecret` | sops-secrets-operator; `tofu/keycloak-management`; o Job de OAuth do Portainer | Sync; `plan` e `apply` do `management` | client secret do `portainer` e senha do admin local do Portainer |
| `argocd/apps/satellites/blog/cloudflared/templates/tunnel-token.sops-secret.yaml` | `SopsSecret` | sops-secrets-operator | Sync | token do túnel Cloudflare |
| `argocd/apps/satellites/blog/blog/templates/admin-oidc.sops-secret.yaml` | `SopsSecret` | sops-secrets-operator; `tofu/keycloak-homelab` (pelo `secrets.map`) | Sync; `plan` e `apply` do `homelab` | client secret do `blog` no realm `homelab`, montado no blog como `/secrets/app/PORTFOLIO_ADMIN_OIDC_CLIENT_SECRET` |

A regra que organiza a tabela: um segredo vive ao lado de quem o consome no cluster, e quem mais precisar dele o lê dali. O OpenTofu nunca guarda cópia de um segredo de client; `secrets.map`, em cada módulo do Keycloak, diz de qual arquivo e chave o valor vem, e `tofu-run.sh` o extrai em memória na hora do `plan`. Só o `keycloak-master.sops.env` guarda segredos que não pertencem a consumidor nenhum, porque o administrador e as contas de serviço são do próprio Keycloak.

O prazo de rotação de cada arquivo está em `.config/secret-max-age.conf`, e a CI avisa quando vence. A ordem das linhas desse arquivo importa: a linha dedicada de `keycloak-master.sops.env` precisa vir antes da linha padrão `*`, senão o padrão intercepta o arquivo primeiro e o prazo dedicado nunca é lido. `keycloak-homelab` e `keycloak-management`, sem `.sops.env` próprio, caem direto no prazo padrão, porque não têm linha dedicada nenhuma para a linha padrão interceptar.

## O que o OpenTofu lê, módulo a módulo

- `cloudflare`: `state.sops.env` e `cloudflare.sops.env`. Escreve na Cloudflare; o token do túnel que ele cria nunca passa pelo state, é buscado depois por `just cloudflare-tunnel-token` e gravado no `SopsSecret` do cloudflared.
- `tailscale`: `state.sops.env` e `tailscale.sops.env`, mais o endereço do node lido da API da tailnet.
- `keycloak-master`: `state.sops.env` e `keycloak-master.sops.env`. Escreve no Keycloak: realms, administrador permanente, contas de serviço.
- `keycloak-homelab`: `state.sops.env`; pelo `secrets.map`, o segredo de `tofu-homelab` do `keycloak-master.sops.env` e o segredo do client `blog` do `SopsSecret` `app-secret` do próprio blog. Não tem `.sops.env` próprio.
- `keycloak-management`: `state.sops.env`; pelo `secrets.map`, o segredo de `tofu-management` do `keycloak-master.sops.env` e os client secrets dos `SopsSecret` de `sso`, `oauth2-proxy` e `portainer`. Também sem `.sops.env` próprio.

Os `terraform.tfstate` de cada módulo em `tofu/` são commitados cifrados com a passphrase de `state.sops.env`; perder essa passphrase não derruba nada, só obriga a reimportar os recursos. Commitar o state é o que permite rodar o `plan` de qualquer módulo a partir de um clone limpo, sem backend remoto e sem serviço de locking, o que num operador só é o arranjo mais simples que funciona. O preço é que `apply` simultâneo não existe, e que o diff de um state cifrado não diz nada a quem revisa o pull request.

## O que acontece quando um segredo muda no git

Declarar um segredo no git só vale alguma coisa se a mudança chegar ao serviço, e cada segredo chega por um caminho diferente. A tabela abaixo classifica todas as chaves, uma a uma, por comportamento: **só bootstrap** (o valor é lido uma vez, na criação de algo, e mudá-lo depois não muda nada por si só), **reinicia sozinho** (o consumidor lê por variável de ambiente ou arquivo no start e tem a anotação do Reloader, então o `Secret` novo derruba e recria o pod), **reinicia à mão** (mesma leitura no start, mas sem Reloader, então alguém precisa reiniciar o pod), e **vivo** (o consumidor relê o valor a cada uso, sem restart). Para os arquivos que só o operador lê, a coluna diz qual comando aplica a mudança.

| Chave | Arquivo | Comportamento | Como a mudança chega |
| --- | --- | --- | --- |
| `k3s_join_token` | `secrets.sops.yaml` | só bootstrap na instalação; depois, rotação por playbook | `just rotate-token`: roda `k3s token rotate`, regrava `config.yaml` e reinicia o k3s; um `bootstrap` comum só confere |
| `argocd_github_webhook_secret` | `secrets.sops.yaml` | vivo | próximo `just bootstrap` (`--tags argocd`) grava em `argocd-secret`; o Argo relê esse `Secret` a cada webhook, sem restart |
| `tailscale_auth_key` | `secrets.sops.yaml` | só bootstrap | usada uma vez para entrar na tailnet; depois disso a role a ignora, e uma chave nova só importa numa reinstalação |
| `ssh_hardening_authorized_keys` | `authorized_keys.yml` (texto claro) | vivo no host | próximo `just bootstrap` reconcilia o arquivo; o `sshd` lê `authorized_keys` a cada login |
| `TF_VAR_state_passphrase` | `tofu/state.sops.env` | lida em todo `plan` e `apply` | mudar exige recifrar todo `terraform.tfstate` com um `fallback` no `encryption.tf`; nenhum pod envolvido |
| `CLOUDFLARE_API_TOKEN` e IDs | `cloudflare.sops.env` | lidos em todo `plan` e `apply` | nada no cluster os consome; um token novo vale no próximo comando |
| OAuth client da tailnet | `tailscale.sops.env` | lido em todo `plan` e `apply` | idem |
| `TF_VAR_keycloak_admin_user` e `_password` | `keycloak-master.sops.env` | credencial de login do módulo | precisa refletir a senha real no Keycloak; mudar aqui não muda a senha lá, só como o módulo entra. `just keycloak-bootstrap-admin` a troca do `temp-admin` para o `admin` permanente |
| `TF_VAR_operator_admin_password` | `keycloak-master.sops.env` | vivo por recipe | o provider só grava a senha ao criar o `admin`; `just keycloak-rotate-admin` gera uma nova, aplica pela API e recifra as chaves do arquivo, sem recriar o usuário |
| `TF_VAR_homelab_service_secret`, `TF_VAR_management_service_secret` | `keycloak-master.sops.env` | vivo por `apply` | `just tofu-apply keycloak-master` regrava o segredo do client no Keycloak; os módulos de realm o leem dali pelo `secrets.map` na execução seguinte |
| `PORTFOLIO_ADMIN_OIDC_CLIENT_SECRET` | `SopsSecret` `app-secret` (blog) | reinicia sozinho no blog; vivo por `apply` no Keycloak | o blog lê o arquivo em `/secrets/app` no start e o `Deployment` tem a anotação do Reloader; `just tofu-apply keycloak-homelab` grava o mesmo valor no client `blog` |
| `clientSecret` | `SopsSecret` `argocd-oidc` | vivo em ambos os lados | o Argo relê os `Secret` com o label `part-of: argocd` sem restart; `just tofu-apply keycloak-management` grava o mesmo valor no client |
| `client_secret` | `SopsSecret` `grafana-oidc` | reinicia sozinho | vai por variável de ambiente; o `Deployment` do Grafana tem a anotação do Reloader; o Keycloak recebe pelo `apply` do `management` |
| `client-secret` e `cookie-secret` | `SopsSecret` `oauth2-proxy` | reinicia sozinho | variáveis de ambiente com Reloader; trocar o `cookie-secret` invalida todas as sessões abertas, o que é o efeito desejado numa rotação |
| `client-secret` | `SopsSecret` `portainer-oidc` | vivo por Job | o Job de `PostSync` regrava as configurações de OAuth pela API a cada sync; o Portainer as lê do banco a cada login |
| `password` | `SopsSecret` `portainer-admin` | só bootstrap na criação do admin, e credencial do Job depois | o Portainer só lê `--admin-password-file` ao criar o admin; mudar o valor no git sem mudar a senha no Portainer quebra o Job, que entra com ela. Para rotacionar, mude a senha no Portainer pela API e depois no git, ou apague o banco (PVC) e deixe o pod recriar tudo |
| `token` | `SopsSecret` `cloudflared-secret` | reinicia sozinho | o cloudflared lê `--token-file` no start e o `Deployment` tem a anotação do Reloader; `just cloudflare-tunnel-token` e push bastam |
| certificado de `*.guesant.internal` | `Secret` `internal-domain-tls`, emitido pelo cert-manager | vivo | o Traefik observa o `Secret` e troca o certificado sem restart; a CA que o assina só muda com a rotação descrita em [rotacionar credenciais](rotacionar-credenciais.md) e exige reinstalar a CA nos dispositivos |

A senha do admin do Portainer é o único valor em que o git e o serviço podem divergir silenciosamente, porque o Portainer não a relê; é por isso que ela só serve ao Job e a rotação dela passa pela API. Todo o resto da tabela ou é relido a cada uso, ou chega por um restart que o Reloader dispara, e nos dois casos a divergência se resolve sozinha ou aparece na hora como falha de login. A saída de emergência do Portainer continua sendo apagar o PVC e deixar o pod recriar o admin a partir do arquivo, ao custo de perder as configurações que não estão no git.

O outro caso que a tabela deixa explícito é o do Keycloak: tudo o que ele recebe passa por um `apply` do operador, com Touch ID. Um segredo de client mudado no git vale para o consumidor no próximo sync do Argo, mas só vale para o Keycloak depois do `apply`, e nesse intervalo o login daquele client falha. O intervalo costuma ser curto quando a mudança é deliberada, porque o `apply` vem logo depois do push, mas ele existe e é uma das razões de o `plan` de cada módulo do Keycloak entrar na revisão periódica.

## O que é bootstrap e o que é manutenção

Bootstrap é o que só acontece quando o node ou o Keycloak nascem:

- o primeiro `just bootstrap`, que instala tudo e gera no node a chave age, registrada em `.sops.yaml` com `just sops-recipients` e seguida de `just sops-sync`;
- o primeiro `apply` de cada módulo do Tofu, que cria o que ainda não existe;
- ligar o node à tailnet com uma chave de autorização, que só serve para entrar;
- criar o seu usuário em cada realm com `just keycloak-user`, com e-mail e no grupo `admins`;
- instalar a CA interna nos dispositivos;
- `just keycloak-bootstrap-admin`, que apaga o `temp-admin` e troca a credencial do módulo `master` pelo administrador permanente.

Cada um desses passos deixa um rastro no repositório, seja um state, um destinatário ou um `SopsSecret`, e não precisa ser repetido. Esse rastro é o que separa bootstrap de manutenção na prática, porque repetir um passo de bootstrap ou não faz nada, ou cria uma segunda cópia de algo que deveria ser único, como uma identidade age a mais no `keys.txt` do node. Na dúvida sobre se um passo já aconteceu, é o git que responde, não o cluster.

Manutenção é o que se repete e é idempotente. `just bootstrap` de novo, com ou sem `--tags`, reconcilia o host contra as roles e não muda nada num node que já está como declarado; `just bootstrap-check` antes mostra o que mudaria. Um push em `main` é a manutenção do cluster: o Argo aplica e o Reloader reinicia quem lê segredo por variável.

Fora dessa reconciliação contínua, há a manutenção que alguém dispara. Um `plan` de cada módulo do Tofu, na [revisão periódica](revisao-periodica.md) ou depois de qualquer mudança feita à mão no console, mostra a deriva; o `apply` a corrige. As rotações estão em [rotacionar credenciais](rotacionar-credenciais.md), cada uma com o caminho que faz o valor novo chegar ao serviço. O Renovate cuida das versões, e a CI recusa o que não passa nos gates.

O que não é nem um nem outro, porque vive fora do git, está listado em [estado fora do git](estado-fora-do-git.md): a ACL da tailnet, a expiração da chave do node, os usuários de cada realm, com senha e TOTP, criados com `just keycloak-user` e mantidos só no Keycloak, as configurações do Portainer que o Job reaplica a cada sync, e as identidades privadas que decifram tudo. Nada disso aparece num `plan` nem num diff, então o único mecanismo que cobre esse conjunto é a revisão periódica. É também por isso que a lista existe escrita: um item esquecido ali não quebra gate nenhum, apenas some.

## Continue por aqui

O passo a passo do primeiro dia está em [primeiro bootstrap](primeiro-bootstrap.md); o desenho de cada camada, em [Ansible](../arquitetura/ansible.md), [GitOps](../arquitetura/gitops-root-e-satelites.md), [OpenTofu](../arquitetura/opentofu.md), [Tailscale](../arquitetura/tailscale.md) e [Ingress](../arquitetura/ingress.md).
