# Rotacionar credenciais

Cinco credenciais têm rotina de rotação própria. Três vivem no node, cada uma num playbook separado de `site.yml`: duas do k3s, que interrompem o cluster por alguns segundos, e a chave age do sops-secrets-operator, que não interrompe nada mas precisa do passo extra de resincronizar `.sops.yaml`. Duas vivem na Cloudflare: o token do túnel do blog e o API token que o OpenTofu usa. Nenhuma delas deve mudar como efeito colateral de um bootstrap ou de um `apply`.

## Certificados

```bash
just rotate-certs -K
```

Para o k3s, roda `k3s certificate rotate`, sobe de novo, espera o API server responder e traz o kubeconfig novo para `ansible/kubeconfig`. O kubeconfig anterior deixa de funcionar no mesmo instante, então qualquer outra cópia dele (em outra máquina, num CI) precisa ser substituída. Os certificados do k3s valem um ano e o próprio k3s os renova ao reiniciar quando faltam menos de 90 dias; esta rotina é para rotação deliberada, como depois de um kubeconfig exposto.

## Token de join

```bash
just rotate-token -K
```

Lê o token atual em `/var/lib/rancher/k3s/server/token`, gera um novo com `openssl rand`, roda `k3s token rotate` e reinicia o k3s. Num cluster de um nó só o token não é usado por ninguém depois da instalação, então rotacioná-lo custa só o restart; vale fazer se o node foi clonado ou se o token apareceu em algum log.

## Chave age do node

Rotacionar essa chave é em duas fases, porque `.sops.yaml` e o `Secret` do node precisam ficar consistentes o tempo todo, nunca um sem o outro:

```bash
just rotate-age-key -K
```

Isso gera uma identidade nova, **acrescenta** ela ao `keys.txt` do `Secret` (a antiga continua lá) e reinicia o sops-secrets-operator; nenhum `SopsSecret` para de decifrar nesse meio-tempo, porque `age` tenta cada identidade do arquivo até uma funcionar. Em seguida:

```bash
just sops-recipients sync-node
just sops-sync
```

O primeiro escreve a chave pública nova em `.sops.yaml`; revise o diff e commite. O segundo recifra todo `SopsSecret` já commitado para os destinatários atuais. Só depois disso, com a chave nova já sendo a única referenciada em `.sops.yaml` e todo segredo já recifrado, feche a rotação removendo a identidade antiga:

```bash
just rotate-age-key -K -e sops_age_key_prune=true
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

A passphrase do state é comum a todo módulo, então a troca passa por todos eles. Em `tofu/state.sops.env` (`just sops-edit`), mova o valor atual para uma variável nova, `TF_VAR_state_passphrase_previous`, e coloque a passphrase nova em `TF_VAR_state_passphrase`. Em cada módulo, declare `variable "state_passphrase_previous"` e acrescente ao `encryption.tf` um segundo `key_provider "pbkdf2"` e um `method` com ela, referenciados num bloco `fallback` dentro de `state` e de `plan`. Rode `just tofu-apply <módulo>` em cada um, sem mudança de recurso: o OpenTofu lê o state com a antiga e o grava com a nova. Depois remova o `fallback`, a variável e a entrada `_previous`, e commite os states regravados.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
