# Rotacionar credenciais

Cada credencial abaixo tem rotina de rotação própria. Três vivem no node, cada uma num playbook separado de `site.yml`: duas do k3s, que interrompem o cluster por alguns segundos, e a chave age do sops-secrets-operator, que não interrompe nada mas precisa do passo extra de resincronizar `.sops.yaml`. Duas vivem na Cloudflare: o token do túnel do blog e o API token que o OpenTofu usa. Nenhuma delas deve mudar como efeito colateral de um bootstrap ou de um `apply`.

## Certificados

```bash
just rotate-certs
```

Para o k3s, roda `k3s certificate rotate`, sobe de novo, espera o API server responder e traz o kubeconfig novo para `ansible/kubeconfig`. O kubeconfig anterior deixa de funcionar no mesmo instante, então qualquer outra cópia dele (em outra máquina, num CI) precisa ser substituída. Os certificados do k3s valem um ano e o próprio k3s os renova ao reiniciar quando faltam menos de 90 dias; esta rotina é para rotação deliberada, como depois de um kubeconfig exposto.

## Token de join

```bash
just rotate-token
```

Lê o token atual em `/var/lib/rancher/k3s/server/token`, gera um novo com `openssl rand`, roda `k3s token rotate` e reinicia o k3s. Num cluster de um nó só o token não é usado por ninguém depois da instalação, então rotacioná-lo custa só o restart; vale fazer se o node foi clonado ou se o token apareceu em algum log. Depois de rotacionar, rode `just k3s-token-escrow`, que busca o token novo por SSH e o grava cifrado em `node/k3s-token.sops.env`; sem isso, a cópia de recuperação fica com o token antigo.

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

## Segredo do webhook do GitHub

O segredo que o GitHub usa para assinar os eventos de push enviados ao Argo CD mora cifrado em `ansible/group_vars/all/secrets.sops.yaml`, em `argocd_github_webhook_secret`, e existe em mais dois lugares: no `argocd-secret`, na chave `webhook.github.secret`, e na configuração do webhook do repositório no GitHub. Os três precisam bater. Enquanto não batem, o Argo recusa a assinatura e volta a descobrir commits só pelo polling de três minutos, sem quebrar nada.

Gere o valor e grave-o sem que ele passe pela tela nem pela linha de comando:

```bash
new="$(openssl rand -hex 32)"
printf '"%s"' "$new" | SOPS_AGE_KEY_FILE=~/.config/hl-infrastructure/sops/operator-se.txt sops set --value-stdin ansible/group_vars/all/secrets.sops.yaml '["argocd_github_webhook_secret"]'
printf '{"config":{"url":"https://ops.guesant.net/api/webhook","content_type":"json","insecure_ssl":"0","secret":"%s"}}' "$new" | gh api -X PATCH repos/guesant/hl-infrastructure/hooks/<id> --input -
unset new
```

O id do webhook sai de `gh api repos/guesant/hl-infrastructure/hooks`. Depois, `just bootstrap` grava o valor novo no `argocd-secret`: a role `argocd` compara o que está no cluster com o valor cifrado e só reaplica quando os dois diferem, e o `argocd-server` lê a mudança sem reiniciar. Por fim, confira em `gh api repos/guesant/hl-infrastructure/hooks/<id>/deliveries` que a entrega seguinte de `push` voltou com status 200. Commite o `secrets.sops.yaml`.

## Prazos de rotação

O job `secret-age` da CI e `just lint-secret-age` leem a data `lastmodified` que o SOPS grava em cada arquivo cifrado e comparam com os prazos de `.config/secret-max-age.conf`: 90 dias para `tofu/cloudflare/cloudflare.sops.env`, 180 para o token do túnel, 365 para a passphrase do state e para o client secret do Google, e 180 para qualquer arquivo novo sem regra própria. Num push o job só anota um aviso; na execução agendada diária ele falha, o que deixa o workflow vermelho e faz o GitHub avisar por e-mail. A recipe local só relata, nunca falha.

Dois limites vêm dessa escolha. O prazo é por arquivo, não por valor: trocar só o API token da Cloudflare zera também o relógio dos dois IDs, que moram no mesmo arquivo. E a data mede a última vez que o arquivo foi recifrado, não a última troca de valor: `just sops-rotate`, que troca só a chave de dados, zera a contagem sem o segredo ter mudado, enquanto `just sops-sync` sobre um arquivo já cifrado, que só atualiza destinatários, não mexe nela. Segredos fora do git, como o segredo do webhook, o PAT do Renovate e os certificados do k3s, não entram nessa conta.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
