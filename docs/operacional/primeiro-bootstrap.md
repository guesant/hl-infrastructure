# Primeiro bootstrap

Este runbook parte de um Raspberry Pi limpo, com Raspberry Pi OS e acesso por SSH, e termina com um cluster k3s rodando Cilium, cert-manager, CloudNativePG, ArgoCD, o sops-secrets-operator e o Kargo. O Ansible leva o node cru até o ArgoCD e a aplicação raiz; dali, o Argo instala o resto a partir do git. Rodar o playbook de novo é esperado, não erro: vários passos aqui só preenchem um segredo que faltava antes de repetir o bootstrap.

## Antes de começar

Você precisa de acesso SSH por chave ao Pi como root, e do [Ansible](https://docs.ansible.com/) instalado na sua máquina. Nenhuma ferramenta precisa estar pré-instalada no Pi além do próprio SSH: o Ansible cuida de instalar Helm, k3s e tudo o mais. O usuário padrão que a imagem cria, com senha, sudo e login automático no desktop, não é usado por nada; depois do bootstrap, remova-o como descrito em [restaurar o node](restaurar-o-node.md).

## Configure o inventário e as variáveis

Copie o inventário de exemplo e crie o arquivo de segredos cifrado a partir do modelo. Nenhum dos dois existe num clone recém-feito; o repositório versiona só os modelos. Partir deles importa porque eles já trazem todas as chaves que as roles esperam, com valores de exemplo que os asserts das roles e a checagem de placeholders reconhecem como pendência, em vez de deixar uma variável faltando aparecer no meio da execução:

```bash
cp .local/operator/inventory.example.ini .local/operator/inventory.ini
cp ansible/group_vars/all/secrets.example.yml ansible/group_vars/all/secrets.sops.yaml
just sops-sync ansible/group_vars/all/secrets.sops.yaml
just sops-edit ansible/group_vars/all/secrets.sops.yaml
```

A sincronização cifra o arquivo no lugar, ainda com os valores de exemplo, e a edição o abre decifrado só em memória. Edite o inventário com o IP real do Pi, o usuário SSH e o caminho da chave privada. No arquivo de segredos, preencha o segredo do webhook do GitHub com um valor gerado por você, não o de exemplo.

A chave SSH não entra aqui: ela já precisa estar autorizada no Pi para o Ansible conseguir entrar. O bootstrap confere isso antes de qualquer outra coisa, e aborta antes de desligar login por senha se a lista de chaves autorizadas do usuário do inventário estiver vazia.

| Variável ou arquivo | O quê |
| --- | --- |
| `argocd_github_webhook_secret` | Em `secrets.sops.yaml`; gerado por você, nunca o valor de exemplo |
| `ansible/group_vars/all/versions.yml` | Versão de k3s, Helm e de cada chart; versionado, mantido pelo Renovate |

O inventário real não é rastreado pelo git; o arquivo de segredos é, mas só cifrado, e o gate de segredos cifrados da CI falha se algum valor dele estiver em claro. O Ansible mescla os arquivos de variáveis sozinho.

| Fica em `.local/operator/` | Origem |
| --- | --- |
| Inventário | Copiado do exemplo, editado à mão |
| `known_hosts` | Gravado no passo seguinte |
| Kubeconfig | Trazido do Pi pelo bootstrap |

É justamente esse diretório local que a limpeza do repositório preserva ao apagar o resto do que não está no git.

## Confira o acesso e veja o que vai mudar

Antes do contato, fixe a host key do Pi. Confira as impressões digitais que a varredura de chave mostra contra as que o Pi imprime no console rodando o comando abaixo, e só então grave o arquivo; o Ansible recusa conectar sem essa host key.

Esse é o único momento do runbook em que a confiança na máquina não se apoia em nada anterior. Aceitar a chave sem olhar deixaria uma máquina impostora passar por Pi, levando com ela todo o bootstrap, inclusive os segredos:

```bash
# no console do próprio Pi, para comparar a impressão digital
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Na sua máquina, grave a host key confirmada:

```bash
ssh-keyscan <IP do Pi> | tee .local/operator/known_hosts | ssh-keygen -lf -
```

Com a host key gravada, rode as verificações. O preflight é um playbook curto que confirma o que as roles seguintes assumem sem checar de novo: que o node responde, que a distribuição é da família Debian, que a arquitetura é suportada pelos binários que o playbook usa, que a escalada de privilégio chega a uid 0, e que controladores de cgroup o kernel expõe.

Ele não muda nada no node, e tanto a checagem de bootstrap quanto o bootstrap de verdade o executam antes de qualquer outra coisa. Por isso, rodá-lo sozinho aqui serve para ler o relatório com calma:

```bash
just preflight
just bootstrap-check
```

O inventário usa `root`, então nenhuma receita pede senha, e o preflight aborta se a conexão não chegar a uid 0. A checagem de bootstrap roda o playbook inteiro com `--check --diff`, mostrando o que seria escrito sem escrever nada, e as roles de chart comparam como dry-run no servidor. Vale ler esse diff linha a linha antes da execução real, a única vez em que a mudança inteira aparece de uma vez; veja [preflight e dry-run](preflight-e-dry-run.md).

## Rode o bootstrap

```bash
just bootstrap
```

O playbook aplica as roles do hardening do sistema operacional ao Cilium, ArgoCD e a aplicação raiz; veja [Ansible: as roles do bootstrap](../arquitetura/ansible.md) para a ordem completa. Cada role espera a anterior ficar pronta antes de seguir, então falha no meio do caminho não deixa o cluster pela metade em silêncio. Duas etapas, a de pré-requisitos e o k3s, podem reiniciar a máquina quando a configuração muda; nos dois casos o playbook espera a volta e segue de onde parou.

CloudNativePG, cert-manager, o sops-secrets-operator e o Kargo não têm role própria: a partir do momento em que a aplicação raiz existe, é o Argo quem os traz, como aplicação de plataforma.

A role de bootstrap da aplicação cria essa raiz: copia o diretório root para o node, troca a URL do repositório pela variável correspondente e aplica raiz e projetos por server-side apply, só depois de um diff mostrar diferença. Daí em diante, instalar um componente novo vira um commit no repositório, sem passar pelo Ansible.

## Confirme que funcionou

Depois que o playbook terminar sem erro, confirme com os comandos abaixo. A role do k3s traz o kubeconfig do Pi para a máquina do operador e reescreve o endereço do servidor, que no arquivo original aponta para o loopback, pelo IP do inventário. É por isso que a conferência acontece da sua máquina, sem SSH:

```bash
just kubeconfig
kubectl get nodes
kubectl -n argocd get applications
```

O primeiro comando acima imprime a variável `KUBECONFIG` que aponta para o arquivo que o Ansible copiou do Pi; exporte-a antes dos comandos seguintes. Você deve ver o nó do Pi como pronto e a aplicação root do Argo como sincronizada e saudável. A raiz saudável significa que o Argo leu o repositório e criou as aplicações filhas, não que todas já subiram; as de plataforma levam alguns minutos, e a listagem do namespace `argocd` mostra o progresso delas.

## Registre os destinatários do SOPS

A role da chave age já gerou a chave privada do node e imprimiu a pública no output do bootstrap, mas o arquivo de configuração do SOPS ainda não sabe dela. Essa chave nasce num diretório temporário do node, vira um segredo do namespace `sops` e o diretório é apagado em seguida, então a metade privada nunca sai do cluster. No seu Mac, ou onde você roda os comandos `just`, com sops, age e o plugin do Secure Enclave instalados:

```bash
just age-se-keygen
just age-keygen
```

O primeiro comando gera a identidade de rotina do operador, presa à Secure Enclave da sua máquina; guarde o conteúdo do arquivo impresso como nota segura no seu gerenciador de senhas. O segundo gera a chave de desastre; guarde a linha que começa com `AGE-SECRET-KEY-1`, nunca em disco. Com as chaves públicas em mãos:

```bash
just sops-recipients sync-node
just sops-recipients add operator-se <pública da identidade SE>
just sops-recipients add dr <pública da chave de desastre>
```

Revise o diff do arquivo de destinatários do SOPS e commite. A partir daqui, cifrar um segredo novo não precisa de chave privada, já que a cifragem usa só as chaves públicas listadas ali; quando o arquivo já está cifrado, o mesmo comando reajusta os destinatários existentes, e aí precisa de uma identidade que decifre, a do Secure Enclave ou a de desastre. Veja [adicionar um satélite novo](adicionar-um-satelite.md) para o passo a passo completo.

Num cluster que já tem segredo cifrado, ao contrário deste bootstrap do zero, um destinatário alterado sem recifrar deixa o diff incompleto. Nesse caso, rode a sincronização sem argumento antes de commitar, para reajustar de uma vez todo segredo do Kubernetes, arquivo de ambiente do OpenTofu e arquivo de segredos do Ansible cifrados neste repositório, não só o arquivo que motivou a mudança.

## Crie o túnel e o DNS na Cloudflare

O blog só fica acessível de fora depois que o túnel existir. O túnel dispensa abrir qualquer porta no node: a zona pública do firewall libera só o essencial ao SSH, e os serviços web só respondem pela zona da tailnet, listados na tabela abaixo.

No dashboard da Cloudflare, crie um token de API só com as permissões de túnel e DNS, ambas de edição e restritas à sua conta e à zona do blog. O tráfego da internet chega por uma conexão que o cloudflared abre de dentro para fora, nunca o contrário.

| Zona do firewall | Serviços liberados |
| --- | --- |
| Pública | `ssh`, `dhcpv6-client` |
| Tailnet | `http`, `https` |

Gere primeiro a passphrase que cifra o state do OpenTofu. O state guarda em claro tudo o que o provedor leu e escreveu, e como este repositório é público ele só entra no git cifrado, com cifragem obrigatória em cada módulo. O comando abaixo só vale para a primeira vez, pois recusa gerar uma passphrase nova se já existir um state anterior; trocar a passphrase depois é outro comando, descrito em [OpenTofu: a camada da Cloudflare](../arquitetura/opentofu.md).

```bash
just tofu-state-passphrase
```

O comando acima gera a passphrase com `openssl rand -base64 48` e a grava cifrada, sem imprimi-la em lugar nenhum; ela cifra o state de todo módulo, não só o da Cloudflare. A recipe que chama o OpenTofu carrega esse arquivo com `sops exec-env` antes de invocá-lo, então a passphrase chega ao processo como variável de ambiente e em nenhum momento existe em claro no disco.

Em seguida preencha o arquivo de segredos do módulo com o token de API, o ID da conta e o ID da zona. Cada módulo tem seu próprio arquivo de segredos ao lado dos `.tf`, e é essa separação que mantém a credencial da Cloudflare fora do ambiente dos módulos do Keycloak e do Tailscale. A edição abre o arquivo decifrado no editor e o recifra ao sair, sem deixar cópia em claro:

```bash
just sops-edit tofu/cloudflare/cloudflare.sops.env
```

Esses IDs não são credencial, mas ficam cifrados para este repositório público não apontar para a sua conta. Os hostnames, ao contrário, ficam em texto claro nas variáveis do módulo, listadas na tabela abaixo. O do blog aparece em mais de um lugar e precisa ser o mesmo em todos.

| Variável em `tofu/cloudflare/terraform.tfvars` | Papel |
| --- | --- |
| `blog_hostname` | hostname público do blog; precisa bater com `PUBLIC_SITE_BASE_URL` no `values.yaml` do blog |
| `ops_hostname` | recebe o webhook do GitHub |
| `auth_hostname` | onde o Keycloak responde de fora |

Com isso no lugar, crie os recursos. A inicialização baixa o provedor e o planejamento mostra o que seria criado, os dois pela mesma recipe, que repassa o subcomando ao OpenTofu sem perguntar nada. Aplicar tem recipe própria, com uma confirmação interativa antes de mudar infraestrutura real; a separação existe para que o passo destrutivo não passe despercebido no meio de uma sequência de comandos de leitura:

```bash
just tofu cloudflare init
just tofu cloudflare plan
just tofu-apply cloudflare
```

O planejamento só cria recursos, nunca altera nem destrói: o túnel, o ingress, os registros DNS e o rate limit de login, declarados respectivamente em `tofu/cloudflare/dns.tf` e `tofu/cloudflare/waf.tf`. Se o domínio já tiver registro nesses nomes, como um CNAME antigo no apex, importe-o com a recipe de importação antes do planejamento, senão o apply falha ao criar um nome que já existe.

Um valor de exemplo esquecido barra a execução antes de qualquer chamada à API: a recipe recusa segredo com o prefixo de exemplo, e as validações recusam ID fora do formato e hostname de um domínio reservado para exemplo.

Criado o túnel, traga o token dele e confira que não sobrou pendência. O token não sai do planejamento nem do state: quem o emite é a API da Cloudflare, e a recipe a consulta usando o ID do túnel que o módulo publica como saída. Rode os dois na ordem, porque a checagem de pendências só tem o que conferir depois que o token estiver gravado:

```bash
just cloudflare-tunnel-token
just placeholders
```

O primeiro comando busca o token do túnel recém-criado e o grava cifrado no segredo do cloudflared. O segundo decifra em memória todo arquivo SOPS e só pode terminar dizendo que não há nada pendente; ele mostra os nomes das chaves que ainda têm valor de exemplo, nunca os valores, e confere que o hostname bate nos lugares esperados.

A varredura cobre os segredos do Argo, os arquivos de ambiente do OpenTofu e as variáveis do Ansible. Ela ainda chama o lint que procura valor de exemplo em arquivo não cifrado. Um placeholder esquecido em qualquer das duas formas aparece no mesmo relatório.

Commite junto os arquivos listados na tabela abaixo e faça push; o Argo sobe o cloudflared com o token novo. Eles vão no mesmo commit porque o state cifrado e o lock descrevem a execução que criou aquele túnel, e separá-los deixaria a história sem reconstruir o que existe na Cloudflare.

Quem transforma o push em segredo do Kubernetes é o sops-secrets-operator. Ele decifra com a chave age do node e cria o segredo que o pod do cloudflared monta.

| Arquivo do commit | Conteúdo |
| --- | --- |
| `tofu/cloudflare/cloudflare.sops.env` | cifrado, credenciais do módulo |
| `tofu/cloudflare/terraform.tfstate` | cifrado, estado do módulo |
| `tofu/cloudflare/.terraform.lock.hcl` | versões travadas do provedor |
| `tofu/cloudflare/terraform.tfvars` | hostnames em texto claro |
| segredo do cloudflared | cifrado, token do túnel |

Resta ligar o webhook. Em Settings, Webhooks do repositório no GitHub, aponte-o para `https://ops.guesant.net/api/webhook`, com content type `application/json` e o mesmo valor do segredo do webhook, já registrado no arquivo de segredos do Ansible, como secret. Veja [OpenTofu: a camada da Cloudflare](../arquitetura/opentofu.md) para o porquê de cada peça.

## Ligue o node à tailnet

O bootstrap já instalou o Tailscale, mas pulou o passo de entrar na tailnet, porque a chave de autenticação ainda era o valor de exemplo. A role trata isso como estado esperado: vê que o node não está na tailnet e que a chave começa com o prefixo de exemplo, imprime o que falta e pula o resto de si mesma.

No console de administração do Tailscale, em Settings, Keys, gere uma auth key reutilizável, de preferência com uma tag se a ACL tiver um dono para ela. Um node com tag não tem chave que expira.

Grave a chave e rode o bootstrap de novo. Rodar o playbook inteiro é o caminho normal aqui, e não um desperdício: as outras roles encontram tudo do jeito que deixaram e não mudam nada. A chave em si é escrita num arquivo temporário só em memória, com permissão restrita ao próprio processo, lida de lá pelo comando que entra na tailnet e apagada logo em seguida, então ela não aparece no log nem fica no disco do node:

```bash
just sops-edit ansible/group_vars/all/secrets.sops.yaml
just bootstrap
```

Na saída da role do Tailscale, o node entra na tailnet e o resolvedor local passa a responder pelo domínio interno com o endereço dele. Se o node não tiver tag, volte ao console, em Machines, e desligue a expiração da chave dele. O resolvedor fica configurado para escutar só na interface da tailnet e sem nenhum servidor upstream, então ele responde a zona interna para quem está na tailnet e não serve de resolvedor aberto para mais ninguém.

Falta o split DNS, que é o OpenTofu quem declara. Crie um cliente OAuth em Settings, OAuth clients, com os dois escopos da tabela abaixo, grave o ID e o secret e aplique o módulo. Os escopos correspondem ao que o módulo faz: procura o dispositivo pelo hostname declarado, daí a leitura, e usa o IPv4 encontrado como servidor do split DNS, daí a escrita; nenhum permite mexer em ACL ou em outros dispositivos da tailnet.

| Escopo OAuth | Uso pelo módulo |
| --- | --- |
| `devices:core:read` | encontra o node pelo hostname declarado em `tofu/tailscale/terraform.tfvars` |
| `dns:write` | grava o split DNS com o IPv4 encontrado |

```bash
just sops-edit tofu/tailscale/tailscale.sops.env
just tofu tailscale init
just tofu tailscale plan
just tofu-apply tailscale
```

O planejamento deve criar só o split DNS do domínio interno apontando para o endereço do node. Se esse split DNS já existir no console, importe-o antes com `just tofu tailscale import`; se ele reclamar que o dispositivo não foi encontrado, o node ainda não entrou na tailnet com o hostname declarado no módulo. Commite o state cifrado.

Para conferir de um dispositivo da tailnet, um SSH ao endereço do node deve entrar, e uma consulta DNS a um nome do domínio interno deve devolver esse endereço; de fora da tailnet, o nome não resolve.

Todos os nomes internos devolvem esse mesmo endereço, porque existe um node só. Quem separa um serviço do outro é o Ingress, pelo nome que o cliente manda no cabeçalho da requisição; veja [Tailscale: acesso remoto e DNS interno](../arquitetura/tailscale.md) para o que cada peça faz.

## Crie os realms do Keycloak com o OpenTofu

Os realms são criados e mantidos por três módulos do OpenTofu, na ordem master, management, homelab, listados na tabela abaixo. Eles falam com o Keycloak pelo nome interno, então precisam da tailnet e da CA interna, já commitada ao lado de cada módulo. O módulo master já traz o administrador e as contas de serviço cifrados; os outros leem seus segredos de segredos do Kubernetes por um mapa próprio, conferíveis com a checagem de pendências.

| Módulo | Ordem | Autentica com |
| --- | --- | --- |
| `tofu/keycloak-master` | 1º | administrador de bootstrap, depois o administrador permanente |
| `tofu/keycloak-management` | 2º | conta de serviço que o master cria |
| `tofu/keycloak-homelab` | 3º | conta de serviço que o master cria |

Num cluster que acabou de nascer o realm master não tem usuário nenhum, e ele precisa de alguém para entrar. Crie no chart do Keycloak um segredo cifrado com as duas variáveis da tabela abaixo, cifre, commite e espere o Argo reiniciar o pod. O Keycloak só lê essas variáveis enquanto o master está vazio, então elas não têm efeito depois.

| Variável do segredo `keycloak-bootstrap-admin` | Valor |
| --- | --- |
| `KC_BOOTSTRAP_ADMIN_USERNAME` | `temp-admin` |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | a mesma senha que o arquivo de segredos do módulo master declara como credencial |

```bash
just tofu keycloak-master init && just tofu keycloak-master plan && just tofu-apply keycloak-master
just tofu keycloak-management init && just tofu keycloak-management plan && just tofu-apply keycloak-management
just tofu keycloak-homelab init && just tofu keycloak-homelab plan && just tofu-apply keycloak-homelab
```

O master entra com o administrador de bootstrap e cria os outros realms, o administrador permanente e as contas de serviço; os outros módulos entram com a sua conta de serviço e criam o conteúdo do realm. A ordem é consequência disso: management e homelab não teriam com que se autenticar antes de o master criar a conta de serviço de cada um. Commite os states cifrados.

O administrador de bootstrap já cumpriu o papel dele na aplicação do módulo master, e um único comando o aposenta. Ele é uma conta com poder total no realm master cuja senha está declarada num segredo que o pod lê ao subir, e manter isso depois que o administrador permanente existe é superfície sem contrapartida. O comando é idempotente, então rodá-lo de novo não estraga nada e serve de conferência:

```bash
just keycloak-bootstrap-admin
```

Ele entra como o administrador permanente que o OpenTofu criou, apaga o administrador temporário do realm master pela API e grava o usuário e a senha permanentes como a credencial do módulo, sem nada em claro passar pelo disco.

Depois, confere que o planejamento do master ficou vazio; esse passo não é decorativo. Se o planejamento vier com alguma linha, a recipe sai com erro, porque uma diferença ali significa que o realm master deixou de ser o que o módulo descreve. Commite o arquivo de segredos.

Nenhum usuário humano está no git, e o administrador do master fica reservado ao OpenTofu. Crie o seu com a recipe, que usa a credencial do módulo para falar com a API e pede a senha temporária no terminal, sem eco. Ela exige a repetição da senha e pelo menos doze caracteres, e chamá-la de novo para um usuário que já existe não duplica ninguém, apenas reaplica a senha e as participações em grupo:

```bash
just keycloak-user master gabriel
just keycloak-user management gabriel gabriel@example.com
just keycloak-user homelab gabriel gabriel@example.com
```

No master o usuário recebe o papel de administrador, e é com ele que você entra no console daí em diante. Nos outros realms ele entra no grupo de administradores, sem o qual autentica e é recusado por todas as aplicações.

O e-mail é obrigatório, pois Grafana e o proxy de OAuth exigem o claim. O nome de usuário precisa bater com a variável que identifica o operador no Job do Portainer. No login inicial o Keycloak obriga a trocar a senha e a cadastrar o TOTP.

Nada sobre esses usuários fica no repositório. A senha do administrador do módulo se rotaciona com uma recipe própria, que a troca no Keycloak e recifra o arquivo de segredos de uma vez. O prazo dessa rotação está declarado num arquivo de configuração, e quem confere se ele venceu é a [revisão periódica](revisao-periodica.md).

## Confie na CA interna

O Argo sobe o ingress sozinho depois do push, e com ele o cert-manager emite uma CA interna e o certificado curinga do domínio interno. Os nomes internos passam a responder por HTTPS pela tailnet, mas o seu navegador ainda não confia no emissor. Imprima o certificado público da CA e instale-o como autoridade confiável no sistema de cada dispositivo que vai usar os nomes:

```bash
just internal-ca
```

A saída é só o certificado público; a chave privada fica no cluster. Depois disso, o ArgoCD e o console de administração do Keycloak abrem sem aviso de um dispositivo da tailnet, este último já respondendo com o administrador do master. Veja [Ingress: os nomes internos pela tailnet](../arquitetura/ingress.md) para o desenho.

## Continue por aqui

Se você quer expor um serviço através deste cluster, veja o guia operacional de [adicionar um satélite novo](adicionar-um-satelite.md). Se quer entender por que o repositório instala tudo via Helm em vez de manifestos vendorizados, veja [Helm e os charts](../arquitetura/helm-e-charts.md) na arquitetura. Se você quer entender os conceitos por trás de cada ferramenta que este bootstrap instala (Ansible, k3s, Cilium, TLS automático, ArgoCD, o padrão de operator), veja a seção [Aprender](../aprender/index.md).
