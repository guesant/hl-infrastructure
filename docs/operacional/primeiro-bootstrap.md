# Primeiro bootstrap

Este runbook parte de um Raspberry Pi limpo, com Raspberry Pi OS instalado e acessível por SSH, e termina com um cluster k3s rodando Cilium, cert-manager, CloudNativePG, ArgoCD, o sops-secrets-operator e o Argo CD Image Updater, todos instalados a partir do chart Helm oficial de cada projeto.

## Antes de começar

Você precisa de acesso SSH por chave ao Pi como root, e do [Ansible](https://docs.ansible.com/) instalado na sua máquina. Nenhuma ferramenta precisa estar pré-instalada no Pi além do próprio SSH: o Ansible cuida de instalar Helm, k3s e tudo o mais. O usuário padrão que a imagem cria, com senha, `sudo` e login automático no desktop, não é usado por nada; depois do bootstrap, remova-o como descrito em [restaurar o node](restaurar-o-node.md).

## Configure o inventário e as variáveis

Copie o inventário de exemplo e crie o arquivo de segredos cifrado a partir do modelo:

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
cp ansible/group_vars/all/secrets.example.yml ansible/group_vars/all/secrets.sops.yaml
just sops-sync ansible/group_vars/all/secrets.sops.yaml
just sops-edit ansible/group_vars/all/secrets.sops.yaml
```

O `sops-sync` cifra o arquivo no lugar, ainda com os valores de exemplo, e o `sops-edit` o abre decifrado só em memória. Edite `ansible/inventory.ini` com o IP real do Pi, o usuário SSH e o caminho da chave privada. No `secrets.sops.yaml`, preencha `k3s_api_allowed_cidrs` com o CIDR real da sua rede (a API do k3s fica bloqueada por firewall para qualquer origem fora dessa lista) e `argocd_github_webhook_secret` com um segredo gerado por você (não o valor de exemplo). A chave SSH não entra aqui: ela já precisa estar autorizada no Pi para o Ansible conseguir entrar, e o bootstrap aborta antes de desligar login por senha se o `authorized_keys` do usuário do inventário estiver vazio.

O inventário real não é rastreado pelo git; o `secrets.sops.yaml` é, mas só cifrado, e o job `sopssecrets` da CI falha se algum valor dele estiver em claro. As versões de k3s, Helm e de cada chart não precisam de nada: elas vivem em `ansible/group_vars/all/versions.yml`, que é versionado e mantido pelo Renovate, e o Ansible mescla os dois arquivos sozinho.

## Confira o acesso e veja o que vai mudar

Antes do primeiro contato, fixe a host key do Pi. Confira as impressões digitais que o `ssh-keyscan` mostra contra as que o próprio Pi imprime no console (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`) e só então grave o arquivo; o Ansible usa `StrictHostKeyChecking=yes` contra ele e recusa conectar sem ele:

```bash
ssh-keyscan <IP do Pi> | tee ansible/known_hosts | ssh-keygen -lf -
```

```bash
just preflight
just bootstrap-check
```

O inventário usa `root`, então nenhuma receita pede senha de `sudo`. O preflight confirma que o Ansible fala com a máquina certa e o `bootstrap-check` mostra, sem aplicar nada, tudo o que a execução real faria; veja [preflight e dry-run](preflight-e-dry-run.md).

## Rode o bootstrap

```bash
just bootstrap
```

O playbook aplica as roles em ordem: hardening de sistema operacional primeiro (cgroups, firewall, atualizações automáticas, sysctl, umask, AppArmor, auditd, SSH, fail2ban), depois k3s, depois Cilium como CNI, depois ArgoCD, depois a aplicação raiz do Argo e a chave age do sops-secrets-operator. Cada role espera o componente anterior ficar pronto antes de seguir, então uma falha no meio do caminho não deixa o cluster pela metade de forma silenciosa. CloudNativePG, cert-manager, o sops-secrets-operator e o Argo CD Image Updater não têm role própria: a partir do momento em que a aplicação raiz existe, é o Argo quem os traz, como `Application` de plataforma.

## Confirme que funcionou

Depois que o playbook terminar sem erro, confirme com:

```bash
just kubeconfig
kubectl get nodes
kubectl -n argocd get applications
```

O comando `just kubeconfig` imprime a variável `KUBECONFIG` que aponta para o arquivo que o Ansible copiou do Pi; exporte-a antes dos dois comandos seguintes. Você deve ver o nó do Pi como `Ready` e a aplicação `root` do Argo como `Synced` e `Healthy`.

## Registre os destinatários do SOPS

A role `sops_age_key` já gerou a chave privada do node e imprimiu a pública no meio do output do `bootstrap`, mas `.sops.yaml` ainda não sabe dela. No seu Mac (ou onde você roda os comandos `just`), com `brew install sops age age-plugin-se` já feito:

```bash
just age-se-keygen
just age-keygen
```

O primeiro gera a identidade de rotina do operador, presa à Secure Enclave da sua máquina; guarde o conteúdo do arquivo impresso como nota segura no seu gerenciador de senhas. O segundo gera a chave de desastre; guarde a privada (a linha `AGE-SECRET-KEY-1...`) no mesmo lugar, nunca em disco. Com as duas públicas em mãos:

```bash
just sops-recipients sync-node
just sops-recipients add operator-se <pública da identidade SE>
just sops-recipients add dr <pública da chave de desastre>
```

Revise o diff de `.sops.yaml` e commite. A partir daqui, `just sops-sync <arquivo>` cifra qualquer `SopsSecret` novo sem precisar de nenhuma chave privada; veja [adicionar um satélite novo](adicionar-um-satelite.md).

## Crie o túnel e o DNS na Cloudflare

O blog só fica acessível de fora depois que o túnel existe. No dashboard da Cloudflare, crie um API token com duas permissões e nada além delas: Cloudflare Tunnel, de edição, restrita à sua conta, e DNS, de edição, restrita à zona do blog. Depois preencha os arquivos que o OpenTofu usa:

```bash
just tofu-state-passphrase
just sops-edit tofu/cloudflare/cloudflare.sops.env
```

O primeiro gera uma passphrase aleatória com `openssl rand -base64 48` e a grava cifrada em `tofu/state.sops.env`, sem imprimi-la em lugar nenhum; ela cifra o state de todo módulo OpenTofu, não só o da Cloudflare. No segundo, coloque o API token, o ID da conta e o ID da zona; os dois IDs não são credencial, mas ficam cifrados para este repositório público não apontar para a sua conta. Os hostnames ficam em texto claro. O do blog aparece em dois lugares, que precisam bater: `blog_hostname` em `tofu/cloudflare/terraform.tfvars` e `PUBLIC_SITE_BASE_URL` no `values.yaml` do blog. O de operação, que recebe o webhook, é `ops_hostname` no mesmo `terraform.tfvars`. Então:

```bash
just tofu cloudflare init
just tofu cloudflare plan
just tofu-apply cloudflare
just cloudflare-tunnel-token
just placeholders
```

O `plan` só pode criar recursos, nunca alterar nem destruir: o túnel, a configuração de ingress e os registros DNS declarados em `tofu/cloudflare/dns.tf`. Se o domínio já tiver registros nesses nomes, como um CNAME antigo no apex, importe-os com `just tofu cloudflare import` antes do `plan`, senão o apply falha ao tentar criar um nome que já existe. Se algum valor de exemplo sobrou, ele nem chega a rodar: o `just tofu` recusa segredo que ainda começa com `REPLACE_WITH_`, e as validações das variáveis recusam ID fora do formato e hostname terminado em `.invalid`. `cloudflare-tunnel-token` busca o token do túnel recém-criado e o grava cifrado no `SopsSecret` do cloudflared. `placeholders` decifra em memória todo arquivo SOPS e só pode terminar dizendo que não há nada pendente; ele mostra os nomes das chaves que ainda têm valor de exemplo, nunca os valores, e confere que o hostname bate nos dois lugares. Commite os dois arquivos `.sops.env`, `terraform.tfstate` (cifrado), `.terraform.lock.hcl`, `terraform.tfvars` e o `SopsSecret` juntos e faça push; o Argo sobe o cloudflared com o token novo. Por fim, em Settings, Webhooks do repositório no GitHub, aponte o webhook para `https://ops.guesant.net/api/webhook`, com content type `application/json` e o mesmo valor de `argocd_github_webhook_secret` como secret. Veja [OpenTofu: a camada da Cloudflare](../arquitetura/opentofu.md) para o porquê de cada peça.

## Ligue o node à tailnet

O bootstrap já instalou o Tailscale e o `dnsmasq`, mas pulou o passo de entrar na tailnet, porque `tailscale_auth_key` ainda era o valor de exemplo. No console de administração do Tailscale, em Settings, Keys, gere uma auth key reutilizável, de preferência com uma tag (`tag:homelab`) se a sua ACL tiver `tagOwners` para ela, porque um node com tag não tem chave que expira. Grave a chave:

```bash
just sops-edit ansible/group_vars/all/secrets.sops.yaml
just bootstrap
```

Na saída da role `tailscale`, o node entra na tailnet e o `dnsmasq` passa a responder `*.guesant.internal` com o endereço dele. Ainda no console, em Machines, desligue a expiração da chave do node, se ele não tiver tag. Depois crie um OAuth client em Settings, OAuth clients, com os escopos `dns:write` e `devices:core:read`, e grave o ID e o secret:

```bash
just sops-edit tofu/tailscale/tailscale.sops.env
just tofu tailscale init
just tofu tailscale plan
just tofu-apply tailscale
```

O `plan` deve criar só o split DNS de `guesant.internal` apontando para o endereço do node; se esse split DNS já existir no console, importe-o antes com `just tofu tailscale import tailscale_dns_split_nameservers.internal guesant.internal`. Se ele reclamar que o dispositivo não foi encontrado, o node ainda não entrou na tailnet com o hostname declarado em `tofu/tailscale/terraform.tfvars`. Commite o state cifrado. Para conferir de um dispositivo da tailnet, `ssh root@<endereço do node na tailnet>` deve entrar e `dig grafana.guesant.internal` deve devolver esse mesmo endereço; de fora da tailnet, o nome não resolve. Veja [Tailscale: acesso remoto e DNS interno](../arquitetura/tailscale.md) para o que cada peça faz.

## Crie os realms do Keycloak com o OpenTofu

Os realms são criados e mantidos pelos três módulos `tofu/keycloak-*`, na ordem `master`, `management`, `homelab`. Eles falam com o Keycloak por `keycloak.guesant.internal`, então precisam da tailnet e da CA interna, já commitada ao lado de cada módulo. O `keycloak-master.sops.env` já traz o administrador e as contas de serviço cifrados, e os outros dois módulos leem seus segredos dos `SopsSecret` pelo `secrets.map`; confira com `just placeholders`.

```bash
just tofu keycloak-master init && just tofu keycloak-master plan && just tofu-apply keycloak-master
just tofu keycloak-management init && just tofu keycloak-management plan && just tofu-apply keycloak-management
just tofu keycloak-homelab init && just tofu keycloak-homelab plan && just tofu-apply keycloak-homelab
```

O `master` entra com o administrador temporário do `Secret` `keycloak-initial-admin` e cria os dois realms, o administrador permanente e as contas de serviço; os outros dois entram com a sua conta de serviço e criam o conteúdo do realm, inclusive o usuário do operador com uma senha temporária. Commite os três states cifrados. O administrador temporário que o operator gerou já cumpriu o papel dele no `apply` do `master`; um único comando o aposenta:

```bash
just keycloak-bootstrap-admin
```

Ele entra como o `admin` permanente que o Tofu criou, apaga o `temp-admin` do realm `master` pela API, grava `admin` e a senha permanente como a credencial do módulo em `keycloak-master.sops.env` (com `sops set`, nada passa em claro pelo disco) e confere que o `plan` do `master` ficou vazio. Commite o `.sops.env`. Depois abra `https://auth.guesant.net/realms/management/account` (e o mesmo em `homelab`), entre com o usuário de `terraform.tfvars` e a senha inicial de `keycloak-master.sops.env`, e o Keycloak obriga a trocar a senha e a cadastrar um TOTP; a partir daí a credencial vive só nele.

## Confie na CA interna

O Argo sobe o ingress sozinho depois do push, e com ele o cert-manager emite uma CA interna e o certificado de `*.guesant.internal`. Os nomes internos passam a responder por HTTPS pela tailnet, mas o seu navegador ainda não confia no emissor. Imprima o certificado público da CA e instale-o como autoridade confiável no sistema de cada dispositivo que vai usar os nomes:

```bash
just internal-ca
```

A saída é só o certificado público; a chave privada fica no cluster. Depois disso, `https://argocd.guesant.internal` e `https://keycloak.guesant.internal` abrem sem aviso de um dispositivo da tailnet, e o console de administração do Keycloak responde nesse segundo nome com o usuário do `Secret` `keycloak-initial-admin`. Veja [Ingress: os nomes internos pela tailnet](../arquitetura/ingress.md) para o desenho.

## Continue por aqui

Se você quer expor um serviço através deste cluster, veja o guia operacional de [adicionar um satélite novo](adicionar-um-satelite.md). Se quer entender por que o repositório instala tudo via Helm em vez de manifestos vendorizados, veja [Helm e os charts](../arquitetura/helm-e-charts.md) na arquitetura. Se você quer entender os conceitos por trás de cada ferramenta que este bootstrap instala (Ansible, k3s, Cilium, TLS automático, ArgoCD, o padrão de operator), veja a seção [Aprender](../aprender/index.md).
