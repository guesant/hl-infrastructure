# Rotacionar credenciais

Cada credencial abaixo tem rotina de rotação própria. Três vivem no node, cada uma num playbook separado de `site.yml`: duas do k3s, que interrompem o cluster por alguns segundos, e a chave age do sops-secrets-operator, que não interrompe nada mas precisa do passo extra de resincronizar `.sops.yaml`. Duas vivem na Cloudflare: o token do túnel do blog e o API token que o OpenTofu usa. Nenhuma delas deve mudar como efeito colateral de um bootstrap ou de um `apply`.

## Certificados

```bash
just rotate-certs
```

Para o k3s, roda `k3s certificate rotate`, sobe de novo, espera o API server responder e traz o kubeconfig novo para `ansible/kubeconfig`. O kubeconfig anterior deixa de funcionar no mesmo instante, então qualquer outra cópia dele (em outra máquina, num CI) precisa ser substituída. Os certificados do k3s valem um ano e o próprio k3s os renova ao reiniciar quando faltam menos de 90 dias; esta rotina é para rotação deliberada, como depois de um kubeconfig exposto.

## CA interna

```bash
kubectl -n cert-manager delete secret internal-ca
kubectl -n ingress delete secret internal-domain-tls
```

O cert-manager percebe o `Secret` da CA ausente, emite outra pelo `ClusterIssuer` autoassinado e, com o certificado do domínio também apagado, reemite `*.guesant.internal` assinado pela CA nova; o Traefik recarrega o certificado sozinho. O passo que não é automático fica do lado dos dispositivos: cada um precisa confiar a CA nova, com a saída de `just internal-ca`, e remover a anterior. Sem rotação deliberada, a CA vale dez anos e mantém a chave ao renovar, de propósito, para que esse passo manual aconteça uma vez só.

## Token de join

```bash
just rotate-token
```

O git é a fonte do valor, não o node: `k3s_join_token`, cifrado em `ansible/group_vars/all/secrets.sops.yaml`, é o token que a role `k3s` grava em `config.yaml` em toda instalação nova, e é para ele que `just rotate-token` converge um node já vivo. Para trocar, gere um valor novo (`openssl rand -hex 32`), grave-o em `k3s_join_token` com `just sops-edit ansible/group_vars/all/secrets.sops.yaml`, e só então rode `just rotate-token`: a playbook lê o token atual do node, compara com o valor declarado e, se forem diferentes, roda `k3s token rotate`, reescreve o `config.yaml` com o valor novo e reinicia o k3s; se já forem iguais, ela não faz nada. A reescrita do `config.yaml` antes do restart não é detalhe: o k3s cifra os dados de bootstrap do datastore com o token do servidor, então um `config.yaml` que ainda dissesse o token antigo faria o k3s subir e não conseguir decifrar o próprio datastore. Num cluster de um nó só o token não é usado por ninguém depois da instalação, então rotacioná-lo custa só o restart; vale fazer se o node foi clonado ou se o token apareceu em algum log. Não há mais uma cópia de recuperação separada: o valor cifrado em `secrets.sops.yaml` já é a fonte, então não existe cópia desatualizada para esquecer de atualizar.

## Chave age do node

Rotacionar essa chave é em duas fases, porque `.sops.yaml` e o `Secret` do node precisam ficar consistentes o tempo todo, nunca um sem o outro:

```bash
just rotate-age-key
```

Isso gera uma identidade nova, **acrescenta** ela ao `keys.txt` do `Secret` (a antiga continua lá) e reinicia o sops-secrets-operator; nenhum `SopsSecret` para de decifrar nesse meio-tempo, porque `age` tenta cada identidade do arquivo até uma funcionar. Em seguida:

```bash
just sops-recipients sync-node
just sops-sync
```

O primeiro escreve a chave pública nova em `.sops.yaml`; revise o diff e commite. O segundo recifra todo `SopsSecret` já commitado para os destinatários atuais. Só depois disso, com a chave nova já sendo a única referenciada em `.sops.yaml` e todo segredo já recifrado, feche a rotação removendo a identidade antiga:

```bash
just rotate-age-key -e sops_age_key_prune=true
```

Rodar `just rotate-age-key` sem a variável de novo, antes de prunar a antiga, só adiciona mais uma identidade; nada quebra, mas também não avança a rotação sozinho.

## Token do túnel Cloudflare

Rotacione o token no dashboard (Networking, Tunnels, o túnel `blog`, Rotate token) e depois traga o novo para o `SopsSecret`:

```bash
just cloudflare-tunnel-token
```

Commite e faça push. O cloudflared que já está rodando continua conectado com o token antigo até reiniciar, porque a rotação só impede conexões novas; o blog não cai entre a rotação e o sync. Quando o Argo aplicar o `Secret` novo, reinicie o Deployment para ele passar a usar o token novo (`kubectl -n blog rollout restart deployment/cloudflared`). Se o motivo da rotação é um token vazado, não espere: derrube também as conexões existentes pela API da Cloudflare antes do push, senão quem tem o token antigo continua conectado. Rodar `just cloudflare-tunnel-token` sem ter rotacionado nada não muda o arquivo.

## API token da Cloudflare e passphrase do state

O API token não tem rotina automática. Crie um token novo no dashboard com as mesmas duas permissões, troque o valor com `just sops-edit tofu/cloudflare/cloudflare.sops.env`, confirme com `just tofu cloudflare plan` que nada muda, e só então revogue o antigo no dashboard.

A passphrase do state é comum a todo módulo, então a troca passa por todos eles:

```bash
just tofu-state-passphrase --rotate
```

Isso gera uma passphrase nova e guarda a atual como `TF_VAR_state_passphrase_previous`, no mesmo arquivo cifrado, sem nenhuma das duas passar pelo terminal. Em cada módulo, declare `variable "state_passphrase_previous"` e acrescente ao `encryption.tf` um segundo `key_provider "pbkdf2"` e um `method` com ela, referenciados num bloco `fallback` dentro de `state` e de `plan`. Rode `just tofu-apply <módulo>` em cada um, sem mudança de recurso: o OpenTofu lê o state com a antiga e o grava com a nova. Por fim:

```bash
just tofu-state-passphrase --finish-rotation
```

Remova o `fallback` e a variável de cada módulo e commite os states regravados junto com o arquivo cifrado.

## Segredos do realm do Keycloak

A senha e o TOTP dos usuários dos realms vivem só no Keycloak e são trocados na conta de cada um (`/realms/<realm>/account`) ou, se perdidos, redefinidos com `just keycloak-user <realm> <usuário>`, que reaplica uma senha temporária e as pertenças sem criar nada duplicado. A senha do `admin` do `master`, a única credencial humana do Keycloak que vive no repositório e que só o OpenTofu usa, se rotaciona com `just keycloak-rotate-admin`: gera uma senha nova, aplica pela API, confirma o login com ela, recifra as duas chaves do `keycloak-master.sops.env` e confere que o `plan` continua vazio; commite o arquivo em seguida. Um client secret vive num lugar só: o `SopsSecret` que o consumidor monta (`sso` para `argocd` e `grafana`, o próprio chart para `oauth2-proxy`, `portainer` e `blog`). O módulo do realm o lê dali pelo `secrets.map`, então a rotação é `just sops-edit` nesse arquivo, `just tofu-apply` do módulo (`keycloak-management` ou `keycloak-homelab`) e push; o consumidor recebe o `Secret` novo pelo sops-secrets-operator, o Reloader reinicia quem lê por variável de ambiente, e o Keycloak passa a aceitar o novo valor no mesmo `apply`. As contas de serviço `tofu-homelab` e `tofu-management` são declaradas em `keycloak-master.sops.env` e lidas de lá pelos outros dois módulos: rotacioná-las é mudar o valor ali e aplicar o `master` antes dos outros. A senha do administrador permanente do `master` vive só em `keycloak-master.sops.env`; mudá-la ali e aplicar é a rotação.

## Segredo do webhook do GitHub

O segredo que o GitHub usa para assinar os eventos de push enviados ao Argo CD mora cifrado em `ansible/group_vars/all/secrets.sops.yaml`, em `argocd_github_webhook_secret`, e existe em mais dois lugares: no `argocd-secret`, na chave `webhook.github.secret`, e na configuração do webhook do repositório no GitHub. Os três precisam bater. Enquanto não batem, o Argo recusa a assinatura e volta a descobrir commits só pelo polling de três minutos, sem quebrar nada.

Gere o valor e grave-o sem que ele passe pela tela nem pela linha de comando:

```bash
new="$(openssl rand -hex 32)"
printf '"%s"' "$new" | SOPS_AGE_KEY_FILE=~/.config/hl-infrastructure/sops/operator-se.txt sops set --value-stdin ansible/group_vars/all/secrets.sops.yaml '["argocd_github_webhook_secret"]'
printf '{"config":{"url":"https://ops.guesant.net/api/webhook","content_type":"json","insecure_ssl":"0","secret":"%s"}}' "$new" | gh api -X PATCH repos/guesant/hl-infrastructure/hooks/<id> --input -
unset new
```

O id do webhook sai de `gh api repos/guesant/hl-infrastructure/hooks`. Para configurar o webhook à mão pela interface do GitHub, em vez do `gh api`, `just webhook-secret | pbcopy` copia o valor atual decifrado para a área de transferência sem mostrá-lo na tela; sem o `pbcopy`, a recipe o imprime. Depois, `just bootstrap` grava o valor novo no `argocd-secret`: a role `argocd` compara o que está no cluster com o valor cifrado e só reaplica quando os dois diferem, e o `argocd-server` lê a mudança sem reiniciar. Por fim, confira em `gh api repos/guesant/hl-infrastructure/hooks/<id>/deliveries` que a entrega seguinte de `push` voltou com status 200. Commite o `secrets.sops.yaml`.

## Rotação pela CI, ainda como rascunho

[.github/workflows/rotate-secrets.yml.example](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/rotate-secrets.yml.example) é um workflow que não roda: a extensão `.example` o mantém fora do GitHub Actions até alguém renomeá-lo, e ele existe para a decisão de trazer parte da rotação para a CI ser tomada olhando um desenho concreto. Ele tem três jobs, cada um preso a um environment próprio com aprovação obrigatória, e cada um termina abrindo um pull request em vez de fazer push em `main`, para que a rotação passe pelos mesmos gates que qualquer outra mudança.

O primeiro roda `sops rotate` em todo arquivo cifrado, o que troca a chave de dados sem mudar nenhum valor. Ele precisa decifrar, então o environment `rotation-sops` guardaria uma identidade age dedicada à CI, que teria de entrar em `.sops.yaml` como mais um destinatário; não seria a identidade da Secure Enclave, que não sai do Mac, nem a chave de desastre, que não deveria sair do Bitwarden. Esse é o custo real da ideia: uma quarta identidade capaz de decifrar tudo, vivendo num secret do GitHub. O segundo job troca o segredo do túnel na Cloudflare e recifra o token novo no `SopsSecret` do cloudflared, com um token da Cloudflare restrito a Cloudflare Tunnel. O terceiro rola o valor do API token do OpenTofu pela própria API da Cloudflare e o recifra em `tofu/cloudflare/cloudflare.sops.env`; para isso ele precisa de um token com permissão de editar tokens, que é praticamente a conta inteira, o que o [desenho do OpenTofu](../arquitetura/opentofu.md) rejeitou para o próprio Tofu e continua sendo a parte mais cara do rascunho.

O que não cabe na CI de propósito: o segredo do webhook, os client secrets do Keycloak e o token de join do k3s precisam de acesso ao cluster ou ao node, e a API do k3s só aceita os CIDRs do operador; a passphrase do state exige recifrar todo state com o `fallback` do OpenTofu; e a chave age do node é rotacionada pelo Ansible. Antes de renomear o arquivo, faltam decidir a identidade age da CI, criar os environments e os secrets que os jobs esperam, e registrar o checksum do `sops` para a arquitetura do runner.

## Prazos de rotação

O job `secret-age` da CI e `just lint-secret-age` leem a data `lastmodified` que o SOPS grava em cada arquivo cifrado e comparam com os prazos de `.config/secret-max-age.conf`: 90 dias para `tofu/cloudflare/cloudflare.sops.env`, 180 para o token do túnel, 365 para a passphrase do state e para o client secret do Google, e 180 para qualquer arquivo novo sem regra própria. Num push o job só anota um aviso; na execução agendada diária ele falha, o que deixa o workflow vermelho e faz o GitHub avisar por e-mail. A recipe local só relata, nunca falha.

Dois limites vêm dessa escolha. O prazo é por arquivo, não por valor: trocar só o API token da Cloudflare zera também o relógio dos dois IDs, que moram no mesmo arquivo. E a data mede a última vez que o arquivo foi recifrado, não a última troca de valor: `just sops-rotate`, que troca só a chave de dados, zera a contagem sem o segredo ter mudado, enquanto `just sops-sync` sobre um arquivo já cifrado, que só atualiza destinatários, não mexe nela. Segredos fora do git, como o segredo do webhook, o PAT do Renovate e os certificados do k3s, não entram nessa conta.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
