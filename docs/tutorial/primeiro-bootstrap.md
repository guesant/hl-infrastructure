# Primeiro bootstrap

Este tutorial parte de um Raspberry Pi limpo, com Raspberry Pi OS instalado e acessível por SSH, e termina com um cluster k3s rodando Cilium, cert-manager, CloudNativePG, o plugin de backup Barman Cloud, ArgoCD, o controlador de Sealed Secrets e o Argo CD Image Updater, todos instalados a partir do chart Helm oficial de cada projeto.

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

O `-K` pede a senha de `sudo` do usuário do inventário; omita se ele tem `sudo` sem senha. O preflight confirma que o Ansible fala com a máquina certa e o `bootstrap-check` mostra, sem aplicar nada, tudo o que a execução real faria; veja [preflight e dry-run](../operacional/preflight-e-dry-run.md).

## Rode o bootstrap

```bash
just bootstrap -K
```

O playbook aplica as roles em ordem: hardening de sistema operacional primeiro (cgroups, firewall, atualizações automáticas, sysctl, auditd, SSH, fail2ban), depois k3s, depois Cilium como CNI, depois CloudNativePG e o plugin de backup, cert-manager, ArgoCD, Sealed Secrets e o Argo CD Image Updater, e por fim a aplicação raiz do Argo. Cada role espera o componente anterior ficar pronto antes de seguir, então uma falha no meio do caminho não deixa o cluster pela metade de forma silenciosa.

## Confirme que funcionou

Depois que o playbook terminar sem erro, confirme com:

```bash
just kubeconfig
kubectl get nodes
kubectl -n argocd get applications
```

O comando `just kubeconfig` imprime a variável `KUBECONFIG` que aponta para o arquivo que o Ansible copiou do Pi; exporte-a antes dos dois comandos seguintes. Você deve ver o nó do Pi como `Ready` e a aplicação `root` do Argo como `Synced` e `Healthy`.

## Continue por aqui

Se você quer expor um serviço através deste cluster, veja o guia operacional de [adicionar um satélite novo](../operacional/adicionar-um-satelite.md). Se quer entender por que o repositório instala tudo via Helm em vez de manifestos vendorizados, veja [Helm e os charts](../arquitetura/helm-e-charts.md) na arquitetura.
