# Primeiro bootstrap

Este runbook parte de um Raspberry Pi limpo, com Raspberry Pi OS instalado e acessível por SSH, e termina com um cluster k3s rodando Cilium, cert-manager, CloudNativePG, ArgoCD, o sops-secrets-operator e o Kargo, todos instalados a partir do chart Helm oficial de cada projeto. O caminho tem duas metades: o Ansible leva o node do sistema operacional cru até o ArgoCD e a aplicação raiz, e daí em diante é o Argo quem instala o resto a partir do que está declarado no git. Executar o playbook mais de uma vez é esperado, não um sinal de erro, porque vários passos daqui consistem em preencher um segredo que ainda faltava e rodar `just bootstrap` de novo.

## Antes de começar

Você precisa de acesso SSH por chave ao Pi como root, e do [Ansible](https://docs.ansible.com/) instalado na sua máquina. Nenhuma ferramenta precisa estar pré-instalada no Pi além do próprio SSH: o Ansible cuida de instalar Helm, k3s e tudo o mais. O usuário padrão que a imagem cria, com senha, `sudo` e login automático no desktop, não é usado por nada; depois do bootstrap, remova-o como descrito em [restaurar o node](restaurar-o-node.md).

## Configure o inventário e as variáveis

Copie o inventário de exemplo e crie o arquivo de segredos cifrado a partir do modelo. Nenhum dos dois existe num clone recém-feito; o repositório versiona só os modelos. Partir deles importa porque eles já trazem todas as chaves que as roles esperam, com valores no formato `REPLACE_WITH_...` que os asserts das roles e o `just placeholders` reconhecem como pendência, em vez de deixar uma variável faltando aparecer no meio da execução:

```bash
cp .local/operator/inventory.example.ini .local/operator/inventory.ini
cp ansible/group_vars/all/secrets.example.yml ansible/group_vars/all/secrets.sops.yaml
just sops-sync ansible/group_vars/all/secrets.sops.yaml
just sops-edit ansible/group_vars/all/secrets.sops.yaml
```

O `sops-sync` cifra o arquivo no lugar, ainda com os valores de exemplo, e o `sops-edit` o abre decifrado só em memória. Edite `.local/operator/inventory.ini` com o IP real do Pi, o usuário SSH e o caminho da chave privada. No `secrets.sops.yaml`, preencha `argocd_github_webhook_secret` com um segredo gerado por você (não o valor de exemplo). A chave SSH não entra aqui: ela já precisa estar autorizada no Pi para o Ansible conseguir entrar, e o bootstrap aborta antes de desligar login por senha se o `authorized_keys` do usuário do inventário estiver vazio.

O inventário real não é rastreado pelo git; o `secrets.sops.yaml` é, mas só cifrado, e o job `sopssecrets` da CI falha se algum valor dele estiver em claro. As versões de k3s, Helm e de cada chart não precisam de nada: elas vivem em `ansible/group_vars/all/versions.yml`, que é versionado e mantido pelo Renovate, e o Ansible mescla os arquivos de variáveis sozinho. Tudo o que é local do operador mora em `.local/operator/`, o inventário, o `known_hosts` e depois o kubeconfig que o bootstrap traz do Pi, e é justamente esse diretório que o `just clean` preserva ao apagar o resto do que não está no git.

## Confira o acesso e veja o que vai mudar

Antes do primeiro contato, fixe a host key do Pi. Confira as impressões digitais que o `ssh-keyscan` mostra contra as que o próprio Pi imprime no console (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`) e só então grave o arquivo; o Ansible usa `StrictHostKeyChecking=yes` contra ele e recusa conectar sem ele. Esse é o único momento do runbook em que a confiança na máquina não se apoia em nada anterior, e aceitar a chave sem olhar deixaria qualquer máquina no meio do caminho passar por Pi, levando com ela todo o resto do bootstrap, inclusive os segredos:

```bash
ssh-keyscan <IP do Pi> | tee .local/operator/known_hosts | ssh-keygen -lf -
```

Com a host key gravada, rode as verificações. O `preflight` é um playbook curto que confirma o que as roles seguintes assumem sem checar de novo, que o node responde, que a distribuição é da família Debian, que a arquitetura é uma das duas para as quais k3s, Helm e o cilium-cli publicam binário, que a escalada de privilégio chega a uid 0, e que controladores de cgroup o kernel expõe. Ele não muda nada no node, e tanto o `bootstrap-check` quanto o `bootstrap` o executam antes de qualquer outra coisa, então rodá-lo sozinho aqui serve para ler o relatório com calma:

```bash
just preflight
just bootstrap-check
```

O inventário usa `root`, então nenhuma receita pede senha de `sudo`, e o próprio preflight aborta explicando isso se a conexão não chegar a uid 0. O `bootstrap-check` roda o playbook inteiro com `--check --diff`, mostrando o conteúdo de cada arquivo que seria escrito sem escrever nenhum, e as roles que instalam chart fazem a comparação como dry-run no servidor. Vale ler esse diff linha a linha antes da primeira execução real, porque é a única ocasião em que a mudança inteira aparece de uma vez; veja [preflight e dry-run](preflight-e-dry-run.md).

## Rode o bootstrap

```bash
just bootstrap
```

O playbook aplica as roles em ordem: hardening de sistema operacional primeiro (cgroups, firewall, atualizações automáticas, sysctl, umask, AppArmor, auditd, SSH, fail2ban), depois k3s, depois Cilium como CNI, depois ArgoCD, depois a aplicação raiz do Argo e a chave age do sops-secrets-operator. Cada role espera o componente anterior ficar pronto antes de seguir, então uma falha no meio do caminho não deixa o cluster pela metade de forma silenciosa. Duas etapas podem reiniciar a máquina, a `os_prerequisites` quando precisa ligar o controlador de cgroup de memória que o containerd exige e a `k3s` quando a configuração declarada muda num node que já tinha k3s instalado; nos dois casos o playbook espera a máquina voltar e segue de onde parou.

CloudNativePG, cert-manager, o sops-secrets-operator e o Kargo não têm role própria: a partir do momento em que a aplicação raiz existe, é o Argo quem os traz, como `Application` de plataforma. Quem cria essa raiz é a role `bootstrap_app`: ela copia `argocd/root/` para o node, troca a URL do repositório pela declarada em `bootstrap_app_repo_url` e aplica os `AppProject` e a `Application` raiz com `kubectl apply --server-side`, só depois de um `diff` mostrar que o cluster está diferente. A partir daí, instalar um componente novo de plataforma deixa de passar pelo Ansible e vira um commit no repositório.

## Confirme que funcionou

Depois que o playbook terminar sem erro, confirme com os comandos abaixo. A role `k3s` traz o `/etc/rancher/k3s/k3s.yaml` do Pi para `.local/operator/kubeconfig` e reescreve o endereço do servidor, que no arquivo original aponta para `127.0.0.1`, pelo IP do inventário. É por isso que a conferência acontece da sua máquina, sem SSH:

```bash
just kubeconfig
kubectl get nodes
kubectl -n argocd get applications
```

O comando `just kubeconfig` imprime a variável `KUBECONFIG` que aponta para o arquivo que o Ansible copiou do Pi; exporte-a antes dos comandos seguintes. Você deve ver o nó do Pi como `Ready` e a aplicação `root` do Argo como `Synced` e `Healthy`. A raiz saudável significa que o Argo leu o repositório e criou as `Application` filhas, não que todas já subiram; as de plataforma levam alguns minutos, e a listagem do namespace `argocd` mostra o progresso delas.

## Registre os destinatários do SOPS

A role `sops_age_key` já gerou a chave privada do node e imprimiu a pública no meio do output do `bootstrap`, mas `.sops.yaml` ainda não sabe dela. Essa chave nasce num diretório temporário do próprio node, vira o `Secret` `sops-age-key-file` do namespace `sops` e o diretório é apagado em seguida, então a metade privada nunca sai do cluster nem chega à sua máquina. No seu Mac (ou onde você roda os comandos `just`), com `brew install sops age age-plugin-se` já feito:

```bash
just age-se-keygen
just age-keygen
```

`just age-se-keygen` gera a identidade de rotina do operador, presa à Secure Enclave da sua máquina; guarde o conteúdo do arquivo impresso como nota segura no seu gerenciador de senhas. `just age-keygen` gera a chave de desastre; guarde a privada (a linha `AGE-SECRET-KEY-1...`) no mesmo lugar, nunca em disco. Com as chaves públicas em mãos:

```bash
just sops-recipients sync-node
just sops-recipients add operator-se <pública da identidade SE>
just sops-recipients add dr <pública da chave de desastre>
```

Revise o diff de `.sops.yaml` e commite. A partir daqui, `just sops-sync <arquivo>` cifra qualquer `SopsSecret` novo sem precisar de nenhuma chave privada, já que cifrar usa só as públicas listadas ali. Quando o arquivo já está cifrado, o mesmo comando roda `updatekeys` para reajustar os destinatários, e aí ele precisa de uma identidade que decifre, a do Secure Enclave ou a de desastre; veja [adicionar um satélite novo](adicionar-um-satelite.md). Num cluster que já tem segredo cifrado, ao contrário deste bootstrap do zero, um `.sops.yaml` alterado sem recifrar deixa o `git diff` incompleto: rode `just sops-sync` sem argumento antes de commitar, para reajustar todo `SopsSecret`, `.sops.env` e `secrets.sops.yaml` de uma vez, não só o arquivo que motivou a mudança.

## Crie o túnel e o DNS na Cloudflare

O blog só fica acessível de fora depois que o túnel existe. O túnel é o que dispensa abrir qualquer porta no node: a zona pública do firewall declara só `ssh` e `dhcpv6-client`, e `http` e `https` aparecem apenas na zona da tailnet, de modo que o tráfego da internet chega por uma conexão que o cloudflared abre de dentro para fora. No dashboard da Cloudflare, crie um API token com estas permissões e nada além delas: Cloudflare Tunnel, de edição, restrita à sua conta, e DNS, de edição, restrita à zona do blog.

Gere primeiro a passphrase que cifra o state do OpenTofu. O state guarda em claro tudo o que o provider leu e escreveu, e este repositório é público, então ele só entra no git cifrado, com a cifragem declarada como `enforced` no bloco `encryption` de cada módulo, o que faz o OpenTofu recusar gravar um state em claro. O comando abaixo só vale para a primeira vez: ele se recusa a gerar uma passphrase nova se já existir algum `terraform.tfstate` em `tofu/`, porque o state existente ficaria ilegível, e para trocá-la depois existe `--rotate`:

```bash
just tofu-state-passphrase
```

Ela sai de `openssl rand -base64 48` e é gravada cifrada em `tofu/state.sops.env`, sem ser impressa em lugar nenhum. Ela cifra o state de todo módulo, não só o da Cloudflare. O `just tofu` carrega esse arquivo com `sops exec-env` antes de chamar o OpenTofu, então a passphrase chega ao processo como variável de ambiente e em nenhum momento existe em claro no disco.

Em seguida preencha o arquivo de segredos do módulo com o API token, o ID da conta e o ID da zona. Cada módulo tem o seu `<módulo>.sops.env` ao lado dos `.tf`, carregado do mesmo jeito que o do state, e é essa separação que mantém a credencial da Cloudflare fora do ambiente em que os módulos do Keycloak e do Tailscale rodam. O `sops-edit` abre o arquivo decifrado no seu editor e o recifra ao sair, sem deixar cópia em claro:

```bash
just sops-edit tofu/cloudflare/cloudflare.sops.env
```

Esses IDs não são credencial, mas ficam cifrados para este repositório público não apontar para a sua conta. Os hostnames, ao contrário, ficam em texto claro em `tofu/cloudflare/terraform.tfvars`: `blog_hostname`, `ops_hostname`, que recebe o webhook, e `auth_hostname`, por onde o Keycloak responde de fora. O do blog aparece em mais de um lugar e precisa ser o mesmo em todos, `blog_hostname` e `PUBLIC_SITE_BASE_URL` no `values.yaml` do blog.

Com isso no lugar, crie os recursos. O `init` baixa o provider e o `plan` mostra o que seria criado, os dois pelo `just tofu`, que repassa o subcomando ao OpenTofu sem perguntar nada. Aplicar tem recipe própria, `just tofu-apply`, com uma confirmação interativa antes de mudar infraestrutura real; a separação existe para que o passo destrutivo não passe despercebido no meio de uma sequência de comandos de leitura:

```bash
just tofu cloudflare init
just tofu cloudflare plan
just tofu-apply cloudflare
```

O `plan` só pode criar recursos, nunca alterar nem destruir: o túnel, a configuração de ingress, os registros DNS de `tofu/cloudflare/dns.tf` e o rate limit dos fluxos de login de `tofu/cloudflare/waf.tf`. Se o domínio já tiver registros nesses nomes, como um CNAME antigo no apex, importe-os com `just tofu cloudflare import` antes do `plan`, senão o apply falha ao tentar criar um nome que já existe. Um valor de exemplo esquecido interrompe a execução antes de qualquer chamada à API: o `just tofu` recusa segredo que ainda começa com `REPLACE_WITH_`, e as validações das variáveis recusam ID fora do formato e hostname terminado em `.invalid`.

Criado o túnel, traga o token dele e confira que não sobrou pendência. O token não sai do `plan` nem do state: quem o emite é a API da Cloudflare, e a recipe a consulta usando o `tunnel_id` que o módulo publica como output. Rode os dois na ordem, porque o `placeholders` só tem o que conferir depois que o token estiver gravado:

```bash
just cloudflare-tunnel-token
just placeholders
```

`cloudflare-tunnel-token` busca o token do túnel recém-criado e o grava cifrado no `SopsSecret` do cloudflared. `placeholders` decifra em memória todo arquivo SOPS e só pode terminar dizendo que não há nada pendente; ele mostra os nomes das chaves que ainda têm valor de exemplo, nunca os valores, e confere que o hostname bate nos lugares esperados. A varredura cobre os `SopsSecret` do Argo, os `.sops.env` do OpenTofu e as variáveis do Ansible, e ainda chama o lint que procura valor de exemplo em arquivo não cifrado, então um `REPLACE_WITH_` esquecido em qualquer das duas formas aparece no mesmo relatório.

Commite os arquivos `.sops.env`, `terraform.tfstate` (cifrado), `.terraform.lock.hcl`, `terraform.tfvars` e o `SopsSecret` juntos e faça push; o Argo sobe o cloudflared com o token novo. Eles vão no mesmo commit porque o state cifrado e o lock descrevem exatamente a execução que criou aquele túnel, e separá-los deixaria um ponto da história em que o repositório não reconstrói o que existe na Cloudflare. Quem transforma o push em `Secret` é o sops-secrets-operator, que decifra o `SopsSecret` com a chave age do node e cria o `Secret` que o pod do cloudflared monta.

Resta ligar o webhook. Em Settings, Webhooks do repositório no GitHub, aponte-o para `https://ops.guesant.net/api/webhook`, com content type `application/json` e o mesmo valor de `argocd_github_webhook_secret` como secret. Veja [OpenTofu: a camada da Cloudflare](../arquitetura/opentofu.md) para o porquê de cada peça.

## Ligue o node à tailnet

O bootstrap já instalou o Tailscale e o `dnsmasq`, mas pulou o passo de entrar na tailnet, porque `tailscale_auth_key` ainda era o valor de exemplo. A role trata isso como estado esperado, não como erro: ela lê o `BackendState` do `tailscale status`, vê que o node não está na tailnet e que a chave ainda começa com `REPLACE_WITH_`, imprime uma mensagem dizendo exatamente o que falta e pula o resto de si mesma. No console de administração do Tailscale, em Settings, Keys, gere uma auth key reutilizável, de preferência com uma tag (`tag:homelab`) se a sua ACL tiver `tagOwners` para ela, porque um node com tag não tem chave que expira.

Grave a chave e rode o bootstrap de novo. Rodar o playbook inteiro é o caminho normal aqui, e não um desperdício: as outras roles encontram tudo do jeito que deixaram e não mudam nada. A chave em si é escrita num arquivo em tmpfs com modo `0600`, lida de lá pelo `tailscale up` e apagada num bloco `always`, então ela não aparece no log nem fica no disco do node:

```bash
just sops-edit ansible/group_vars/all/secrets.sops.yaml
just bootstrap
```

Na saída da role `tailscale`, o node entra na tailnet e o `dnsmasq` passa a responder `*.guesant.internal` com o endereço dele. Se o node não tiver tag, volte ao console, em Machines, e desligue a expiração da chave dele. O `dnsmasq` fica configurado para escutar só na interface `tailscale0` e sem nenhum servidor upstream, então ele responde a zona interna para quem está na tailnet e não serve de resolvedor aberto para mais ninguém.

Falta o split DNS, que é o OpenTofu quem declara. Crie um OAuth client em Settings, OAuth clients, com os escopos `dns:write` e `devices:core:read`, grave o ID e o secret e aplique o módulo. Os dois escopos correspondem ao que o módulo faz: ele procura o dispositivo pelo hostname declarado, daí a leitura, e usa o endereço IPv4 encontrado como servidor de nomes do split DNS, daí a escrita. Nenhum dos dois permite mexer em ACL ou em outros dispositivos da tailnet:

```bash
just sops-edit tofu/tailscale/tailscale.sops.env
just tofu tailscale init
just tofu tailscale plan
just tofu-apply tailscale
```

O `plan` deve criar só o split DNS de `guesant.internal` apontando para o endereço do node. Se esse split DNS já existir no console, importe-o antes com `just tofu tailscale import tailscale_dns_split_nameservers.internal guesant.internal`; se ele reclamar que o dispositivo não foi encontrado, o node ainda não entrou na tailnet com o hostname declarado em `tofu/tailscale/terraform.tfvars`. Commite o state cifrado.

Para conferir de um dispositivo da tailnet, `ssh root@<endereço do node na tailnet>` deve entrar e `dig grafana.guesant.internal` deve devolver esse mesmo endereço; de fora da tailnet, o nome não resolve. Todos os nomes internos devolvem esse mesmo endereço, porque existe um node só; quem separa um serviço do outro é o Ingress, pelo nome que o cliente manda no `Host`. Veja [Tailscale: acesso remoto e DNS interno](../arquitetura/tailscale.md) para o que cada peça faz.

## Crie os realms do Keycloak com o OpenTofu

Os realms são criados e mantidos pelos módulos `tofu/keycloak-*`, na ordem `master`, `management`, `homelab`. Eles falam com o Keycloak por `keycloak.guesant.internal`, então precisam da tailnet e da CA interna, já commitada ao lado de cada módulo. O `keycloak-master.sops.env` já traz o administrador e as contas de serviço cifrados, e os outros módulos leem seus segredos dos `SopsSecret` pelo `secrets.map`; confira com `just placeholders`.

Num cluster que acabou de nascer o realm `master` não tem usuário nenhum, e o `master` precisa de alguém para entrar. Crie no chart `argocd/apps/platform/keycloak` um `SopsSecret` `keycloak-bootstrap-admin` com `KC_BOOTSTRAP_ADMIN_USERNAME=temp-admin` e, em `KC_BOOTSTRAP_ADMIN_PASSWORD`, a mesma senha que o `keycloak-master.sops.env` declara como credencial do módulo; cifre com `just sops-sync`, commite e espere o Argo reiniciar o pod. O Keycloak só lê essas variáveis enquanto o `master` está vazio, então elas não têm efeito depois.

```bash
just tofu keycloak-master init && just tofu keycloak-master plan && just tofu-apply keycloak-master
just tofu keycloak-management init && just tofu keycloak-management plan && just tofu-apply keycloak-management
just tofu keycloak-homelab init && just tofu keycloak-homelab plan && just tofu-apply keycloak-homelab
```

O `master` entra com o administrador de bootstrap e cria os outros realms, o administrador permanente e as contas de serviço; os outros módulos entram com a sua conta de serviço e criam o conteúdo do realm. A ordem é consequência disso: o `management` e o `homelab` não teriam com que se autenticar antes de o `master` criar a conta de serviço de cada um. Commite os states cifrados.

O administrador de bootstrap já cumpriu o papel dele no `apply` do `master`, e um único comando o aposenta. Ele é uma conta com poder total no realm `master` cuja senha está declarada num `SopsSecret` que o pod lê ao subir, e manter isso depois que o administrador permanente existe é superfície sem contrapartida. O comando é idempotente, então rodá-lo de novo não estraga nada e serve de conferência:

```bash
just keycloak-bootstrap-admin
```

Ele entra como o `admin` permanente que o Tofu criou, apaga o `temp-admin` do realm `master` pela API, grava `admin` e a senha permanente como a credencial do módulo em `keycloak-master.sops.env` (com `sops set`, nada passa em claro pelo disco) e confere que o `plan` do `master` ficou vazio. Esse último passo não é decorativo: se o `plan` vier com alguma linha, a recipe sai com erro em vez de dizer que terminou, porque uma diferença ali significa que o realm `master` no cluster deixou de ser o que o módulo descreve. Commite o `.sops.env`.

Nenhum usuário humano está no git, e o `admin` do `master` fica reservado ao OpenTofu. Crie o seu com a recipe, que usa a credencial do módulo para falar com a API e pede a senha temporária no terminal, sem eco. Ela exige a repetição da senha e pelo menos doze caracteres, e chamá-la de novo para um usuário que já existe não duplica ninguém, apenas reaplica a senha e as participações em grupo:

```bash
just keycloak-user master gabriel
just keycloak-user management gabriel gabriel@example.com
just keycloak-user homelab gabriel gabriel@example.com
```

No `master` o usuário recebe o papel `admin`, e é com ele que você entra no console daí em diante. Nos outros realms ele entra no grupo `admins`, sem o qual autentica e é recusado por todas as aplicações. O e-mail é obrigatório porque Grafana e oauth2-proxy exigem o claim, e o nome precisa bater com `OPERATOR_USERNAME` no Job do Portainer (`gabriel`). No login inicial o Keycloak obriga a trocar a senha e a cadastrar o TOTP.

Nada sobre esses usuários fica no repositório. A senha do `admin` do módulo se rotaciona com `just keycloak-rotate-admin`, que a troca no Keycloak e recifra o `.sops.env` de uma vez. O prazo dessa rotação está em `.config/secret-max-age.conf`, e quem confere se ele venceu é a [revisão periódica](revisao-periodica.md).

## Confie na CA interna

O Argo sobe o ingress sozinho depois do push, e com ele o cert-manager emite uma CA interna e o certificado de `*.guesant.internal`. Os nomes internos passam a responder por HTTPS pela tailnet, mas o seu navegador ainda não confia no emissor. Imprima o certificado público da CA e instale-o como autoridade confiável no sistema de cada dispositivo que vai usar os nomes:

```bash
just internal-ca
```

A saída é só o certificado público; a chave privada fica no cluster. Depois disso, `https://argocd.guesant.internal` e `https://keycloak.guesant.internal` abrem sem aviso de um dispositivo da tailnet, e o console de administração do Keycloak responde nesse nome com o `admin` do `master`. Veja [Ingress: os nomes internos pela tailnet](../arquitetura/ingress.md) para o desenho.

## Continue por aqui

Se você quer expor um serviço através deste cluster, veja o guia operacional de [adicionar um satélite novo](adicionar-um-satelite.md). Se quer entender por que o repositório instala tudo via Helm em vez de manifestos vendorizados, veja [Helm e os charts](../arquitetura/helm-e-charts.md) na arquitetura. Se você quer entender os conceitos por trás de cada ferramenta que este bootstrap instala (Ansible, k3s, Cilium, TLS automático, ArgoCD, o padrão de operator), veja a seção [Aprender](../aprender/index.md).
