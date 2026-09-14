# Primeiro bootstrap

Este runbook parte de um Raspberry Pi limpo, com Raspberry Pi OS instalado e acessível por SSH, e termina com um cluster k3s rodando Cilium, cert-manager, CloudNativePG, ArgoCD, o sops-secrets-operator e o Argo CD Image Updater, todos instalados a partir do chart Helm oficial de cada projeto.

## Antes de começar

Você precisa de acesso SSH por chave ao Pi, com um usuário que tenha `sudo`, e do [Ansible](https://docs.ansible.com/) instalado na sua máquina. Nenhuma ferramenta precisa estar pré-instalada no Pi além do próprio SSH: o Ansible cuida de instalar Helm, k3s e tudo o mais.

## Configure o inventário e as variáveis

Copie os dois arquivos de exemplo:

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
cp ansible/group_vars/all/secrets.example.yml ansible/group_vars/all/secrets.yml
```

Edite `ansible/inventory.ini` com o IP real do Pi, o usuário SSH e o caminho da chave privada. Edite `ansible/group_vars/all/secrets.yml` preenchendo as três variáveis: `k3s_api_allowed_cidrs` com o CIDR real da sua rede (a API do k3s fica bloqueada por firewall para qualquer origem fora dessa lista), `ssh_root_authorized_key` com a chave pública que vai autorizar login como root, e `argocd_github_webhook_secret` com um segredo gerado por você (não o valor de exemplo).

Nenhum dos dois arquivos reais é rastreado pelo git; só os `.example` ficam versionados. As versões de k3s, Helm e de cada chart não precisam de nada: elas vivem em `ansible/group_vars/all/versions.yml`, que é versionado e mantido pelo Renovate, e o Ansible mescla os dois arquivos sozinho.

## Confira o acesso e veja o que vai mudar

```bash
just preflight -K
just bootstrap-check -K
```

O `-K` pede a senha de `sudo` do usuário do inventário; omita se ele tem `sudo` sem senha. O preflight confirma que o Ansible fala com a máquina certa e o `bootstrap-check` mostra, sem aplicar nada, tudo o que a execução real faria; veja [preflight e dry-run](preflight-e-dry-run.md).

## Rode o bootstrap

```bash
just bootstrap -K
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

O blog só fica acessível de fora depois que o túnel existe. No dashboard da Cloudflare, crie um API token com duas permissões e nada além delas: Cloudflare Tunnel, de edição, restrita à sua conta, e DNS, de edição, restrita à zona do blog. Depois preencha os dois arquivos que o OpenTofu usa:

```bash
just sops-edit tofu/cloudflare/cloudflare.sops.env
```

Troque os dois valores de exemplo pelo API token e por uma passphrase aleatória de pelo menos 32 caracteres (`openssl rand -base64 48` serve), e guarde a passphrase também no seu gerenciador de senhas. Em `tofu/cloudflare/terraform.tfvars`, que não é secreto, coloque o ID da conta, o ID da zona e o hostname real do blog. Então:

```bash
just tofu-cloudflare init
just tofu-cloudflare plan
just tofu-cloudflare-apply
just cloudflare-tunnel-token
```

O `plan` precisa mostrar exatamente três recursos novos: o túnel, a configuração de ingress e o registro DNS. `cloudflare-tunnel-token` busca o token do túnel recém-criado e o grava cifrado no `SopsSecret` do cloudflared. Commite `terraform.tfstate` (cifrado), `.terraform.lock.hcl`, `terraform.tfvars` e o `SopsSecret` juntos e faça push; o Argo sobe o cloudflared com o token novo. Veja [OpenTofu: a camada da Cloudflare](../arquitetura/opentofu.md) para o porquê de cada peça.

## Continue por aqui

Se você quer expor um serviço através deste cluster, veja o guia operacional de [adicionar um satélite novo](adicionar-um-satelite.md). Se quer entender por que o repositório instala tudo via Helm em vez de manifestos vendorizados, veja [Helm e os charts](../arquitetura/helm-e-charts.md) na arquitetura. Se você quer entender os conceitos por trás de cada ferramenta que este bootstrap instala (Ansible, k3s, Cilium, TLS automático, ArgoCD, o padrão de operator), veja a seção [Aprender](../aprender/index.md).
