# Rotacionar credenciais

Cada credencial abaixo tem rotina de rotação própria. Os certificados e o token de join do k3s vivem no node, cada um num playbook separado de `site.yml`, e interrompem o cluster por alguns segundos; a chave age do sops-secrets-operator também vive lá, mas não interrompe nada, embora precise do passo extra de resincronizar `.sops.yaml`. O token do túnel do blog e o API token que o OpenTofu usa vivem na Cloudflare. Nenhuma delas deve mudar como efeito colateral de um bootstrap ou de um `apply`.

## Certificados

```bash
just rotate-certs
```

Para o k3s, roda `k3s certificate rotate`, sobe de novo, espera o API server responder e traz o kubeconfig novo para `.local/operator/kubeconfig`. O kubeconfig anterior deixa de funcionar no mesmo instante, então qualquer outra cópia dele (em outra máquina, num CI) precisa ser substituída. O próprio k3s já renova os certificados sozinho ao reiniciar, perto do fim da validade deles; esta rotina é para rotação deliberada, como depois de um kubeconfig exposto.

## CA interna

```bash
kubectl -n cert-manager delete secret internal-ca
kubectl -n ingress delete secret internal-domain-tls
```

O cert-manager percebe o `Secret` da CA ausente, emite outra pelo `ClusterIssuer` autoassinado e, com o certificado do domínio também apagado, reemite `*.guesant.internal` assinado pela CA nova; o Traefik recarrega o certificado sozinho. O passo que não é automático fica do lado dos dispositivos: cada um precisa confiar a CA nova, com a saída de `just internal-ca`, e remover a anterior. Sem rotação deliberada, a CA tem validade longa e mantém a chave ao renovar, de propósito, para que esse passo manual aconteça uma vez só.

## Token de join

```bash
just rotate-token
```

O git é a fonte do valor, não o node: `k3s_join_token`, cifrado em `ansible/group_vars/all/secrets.sops.yaml`, é o token que a role `k3s` grava em `config.yaml` em toda instalação nova, e é para ele que `just rotate-token` converge um node já vivo. Não existe cópia de recuperação separada, então também não existe cópia desatualizada para esquecer de atualizar. Tratar o git como origem tem um custo assumido: o valor gravado no node e o valor declarado podem divergir sem ninguém notar, e é essa playbook, não o bootstrap, que reconcilia os dois.

Para trocar, gere um valor novo com `openssl rand -hex 32`, grave-o em `k3s_join_token` com `just sops-edit ansible/group_vars/all/secrets.sops.yaml`, e só então rode `just rotate-token`. A playbook lê o token atual do node e o compara com o valor declarado: se forem diferentes, ela roda `k3s token rotate`, reescreve o `config.yaml` com o valor novo e reinicia o k3s; se já forem iguais, não faz nada. Antes de qualquer uma dessas coisas ela recusa continuar caso o valor declarado tenha menos de 32 caracteres, para uma edição interrompida do arquivo cifrado não virar um token fraco no node.

A reescrita do `config.yaml` antes do restart não é detalhe. O k3s cifra os dados de bootstrap do datastore com o token do servidor, então um `config.yaml` que ainda dissesse o token antigo faria o k3s subir e não conseguir decifrar o próprio datastore. A reescrita usa o mesmo template `config.yaml.j2` da role `k3s`, e não uma edição pontual da linha do token, de modo que o arquivo resultante é idêntico ao que um bootstrap produziria e nenhuma outra opção sai do lugar por acidente.

Num cluster de um nó só ninguém usa o token depois da instalação, então rotacioná-lo custa só o restart. Vale fazer se o node foi clonado ou se o token apareceu em algum log. A playbook não devolve o controle antes de o `/healthz` do API server voltar a responder, com até cinco minutos de tentativas, então o fim do comando já é o cluster de pé de novo.

## Chave age do node

Essa é a chave que o sops-secrets-operator usa para decifrar todo `SopsSecret` dentro do cluster; ela é gerada no próprio node e a metade pública dela é um dos destinatários de `.sops.yaml`. Rotacioná-la passa por etapas, porque o arquivo de destinatários e o `Secret` do node precisam ficar consistentes o tempo todo, nunca um sem o outro. A sequência abaixo mantém as duas identidades válidas no meio do caminho e só descarta a antiga no fim:

```bash
just rotate-age-key
```

Isso gera uma identidade nova, **acrescenta** ela ao `keys.txt` do `Secret` (a antiga continua lá) e reinicia o sops-secrets-operator; nenhum `SopsSecret` para de decifrar nesse meio-tempo, porque `age` tenta cada identidade do arquivo até uma funcionar. A recipe recria o `Secret` `sops-age-key-file` inteiro a partir do `keys.txt` resultante, espera o rollout do operador terminar antes de devolver o controle, e imprime no fim a chave pública atual junto com os passos que ainda faltam. Em seguida:

```bash
just sops-recipients sync-node
just sops-sync
```

O primeiro escreve a chave pública nova em `.sops.yaml`; revise o diff e commite. O segundo recifra todo `SopsSecret` já commitado para os destinatários atuais. Só depois disso, com a chave nova já sendo a única referenciada em `.sops.yaml` e todo segredo já recifrado, feche a rotação removendo a identidade antiga:

```bash
just rotate-age-key -e sops_age_key_prune=true
```

Rodar `just rotate-age-key` sem a variável de novo, antes de prunar a antiga, só adiciona mais uma identidade; nada quebra, mas também não avança a rotação sozinho. O prune não escolhe qual identidade fica: ele mantém o bloco que começa no último marcador `# created:` do `keys.txt`, isto é, a gerada mais recentemente. É daí que vem a ordem exigida acima, porque prunar antes de `just sops-sync` deixaria o operador sem a única identidade capaz de abrir os `SopsSecret` ainda cifrados para a chave antiga.

## Token do túnel Cloudflare

O token do túnel não passa pelo OpenTofu: o módulo `cloudflare` cria o túnel, e o token é buscado depois pela API, com o id do túnel lido do output do módulo e gravado direto no `SopsSecret` do cloudflared, sem nunca entrar no state. Os dois passos são separados por consequência disso, porque a API devolve sempre o token atual, e sem rotacionar antes a recipe não teria nada novo para gravar. Rotacione o token no dashboard (Networking, Tunnels, o túnel `blog`, Rotate token) e depois traga o novo para o `SopsSecret`:

```bash
just cloudflare-tunnel-token
```

Commite e faça push. O cloudflared que já está rodando continua conectado com o token antigo até reiniciar, porque a rotação só impede conexões novas; o blog não cai entre a rotação e o sync. Quando o Argo aplicar o `Secret` novo, reinicie o Deployment para ele passar a usar o token novo (`kubectl -n blog rollout restart deployment/cloudflared`). Rodar `just cloudflare-tunnel-token` sem ter rotacionado nada no dashboard não muda o arquivo.

Se o motivo da rotação é um token vazado, não espere: derrube também as conexões existentes pela API da Cloudflare antes do push, senão quem tem o token antigo continua conectado. É o inverso exato do parágrafo anterior, porque a propriedade que evita indisponibilidade numa rotação de rotina é a mesma que mantém um atacante ligado ao túnel. O blog sai do ar entre derrubar as conexões e o cloudflared novo subir, e nesse cenário esse é o custo certo a pagar.

## API token da Cloudflare e passphrase do state

O API token não tem rotina automática. Crie um token novo no dashboard com as mesmas permissões, troque o valor com `just sops-edit tofu/cloudflare/cloudflare.sops.env`, confirme com `just tofu cloudflare plan` que nada muda, e só então revogue o antigo no dashboard. O `plan` no meio da sequência não é formalidade: ele é a prova de que o token novo enxerga os mesmos recursos que o antigo, já que um escopo menor apareceria ali como erro de autorização ou como um recurso que o módulo acha que precisa recriar.

A passphrase do state é comum a todo módulo, e é ela que cifra os `terraform.tfstate` commitados, de modo que o OpenTofu só lê um state com a mesma chave que o gravou. A troca passa por todos os módulos por isso, e o script se recusa a gerar uma passphrase do zero enquanto existir algum `terraform.tfstate` no repositório, que ficaria ilegível. O caminho para trocar uma que já está em uso é outro:

```bash
just tofu-state-passphrase --rotate
```

Isso gera uma passphrase nova e guarda a atual como `TF_VAR_state_passphrase_previous`, no mesmo arquivo cifrado, sem nenhuma delas passar pelo terminal. Em cada módulo, declare `variable "state_passphrase_previous"` e acrescente ao `encryption.tf` mais um `key_provider "pbkdf2"` e um `method` com ela, referenciados num bloco `fallback` dentro de `state` e de `plan`. Rode `just tofu-apply <módulo>` em cada um, sem mudança de recurso: o OpenTofu lê o state com a antiga e o grava com a nova. Por fim:

```bash
just tofu-state-passphrase --finish-rotation
```

Remova o `fallback` e a variável de cada módulo e commite os states regravados junto com o arquivo cifrado. Esse último comando reescreve `state.sops.env` só com a passphrase nova, então qualquer state que ainda estivesse cifrado com a antiga fica ilegível a partir dali. O script protege as duas pontas da sequência: ele recusa iniciar outra rotação enquanto `TF_VAR_state_passphrase_previous` existir no arquivo, e recusa finalizar quando não há rotação em curso.

## Segredos do realm do Keycloak

A senha e o TOTP dos usuários dos realms vivem só no Keycloak e são trocados na conta de cada um (`/realms/<realm>/account`) ou, se perdidos, redefinidos com `just keycloak-user <realm> <usuário>`, que reaplica uma senha temporária e as pertenças sem criar nada duplicado. Nada disso tem cópia no repositório, o que é deliberado, e não há provedor de identidade externo atrás do Keycloak de onde restaurar essas contas. A consequência prática aparece num desastre: perder o volume do Postgres do Keycloak significa recriar cada usuário à mão.

A senha do `admin` do `master` é a única credencial humana do Keycloak que vive no repositório, e só o OpenTofu a usa. `just keycloak-rotate-admin` gera uma senha nova, aplica pela API, confirma o login com ela, recifra as chaves do `keycloak-master.sops.env` e confere que o `plan` continua vazio; commite o arquivo em seguida. Ela vive só em `keycloak-master.sops.env`, então mudá-la ali com `just sops-edit` e aplicar o módulo também é uma rotação válida, só sem a confirmação que a recipe faz.

Um client secret vive num lugar só, o `SopsSecret` que o consumidor monta (`sso` para `argocd` e `grafana`, o próprio chart para `oauth2-proxy`, `portainer` e `blog`). O módulo do realm o lê dali pelo `secrets.map`, então a rotação é `just sops-edit` nesse arquivo, `just tofu-apply` do módulo (`keycloak-management` ou `keycloak-homelab`) e push. O consumidor recebe o `Secret` novo pelo sops-secrets-operator, o Reloader reinicia quem lê por variável de ambiente, e o Keycloak passa a aceitar o novo valor no mesmo `apply`.

As contas de serviço `tofu-homelab` e `tofu-management` são declaradas em `keycloak-master.sops.env` e lidas de lá pelos outros módulos, então rotacioná-las é mudar o valor ali e aplicar o `master` antes dos outros. Aplicar fora dessa ordem falha de um jeito claro, porque `keycloak-homelab` e `keycloak-management` autenticam no Keycloak justamente com esses segredos e não conseguiriam nem começar o `plan`. É também a razão de o `master` ser o único módulo do Keycloak com arquivo cifrado próprio: ele guarda credenciais que pertencem ao Keycloak, não a um consumidor.

## Segredo do webhook do GitHub

O segredo que o GitHub usa para assinar os eventos de push enviados ao Argo CD mora cifrado em `ansible/group_vars/all/secrets.sops.yaml`, em `argocd_github_webhook_secret`, e existe em mais lugares: no `argocd-secret`, na chave `webhook.github.secret`, e na configuração do webhook do repositório no GitHub. Todos precisam bater. Enquanto não batem, o Argo recusa a assinatura e volta a descobrir commits só pelo polling periódico, sem quebrar nada.

Gere o valor e grave-o sem que ele passe pela tela nem pela linha de comando. Os comandos abaixo cobrem duas dessas pontas de uma vez, o arquivo cifrado e a configuração do webhook no GitHub, para elas não ficarem divergentes entre um passo e outro. O valor só existe numa variável do shell, descartada no fim:

```bash
new="$(openssl rand -hex 32)"
printf '"%s"' "$new" | SOPS_AGE_KEY_FILE=~/.config/hl-infrastructure/sops/operator-se.txt sops set --value-stdin ansible/group_vars/all/secrets.sops.yaml '["argocd_github_webhook_secret"]'
printf '{"config":{"url":"https://ops.guesant.net/api/webhook","content_type":"json","insecure_ssl":"0","secret":"%s"}}' "$new" | gh api -X PATCH repos/guesant/hl-infrastructure/hooks/<id> --input -
unset new
```

O id do webhook sai de `gh api repos/guesant/hl-infrastructure/hooks`. Para configurar o webhook à mão pela interface do GitHub, em vez do `gh api`, `just webhook-secret | pbcopy` copia o valor atual decifrado para a área de transferência sem mostrá-lo na tela; sem o `pbcopy`, a recipe o imprime. A listagem traz também a URL de cada hook, o que basta para saber qual id é o do Argo quando existe mais de um configurado.

Falta levar o valor novo ao cluster. `just bootstrap` o grava no `argocd-secret`: a role `argocd` compara o que está no cluster com o valor cifrado e só reaplica quando eles diferem, e o `argocd-server` lê a mudança sem reiniciar. Confira em `gh api repos/guesant/hl-infrastructure/hooks/<id>/deliveries` que a entrega seguinte de `push` voltou com status 200, e commite o `secrets.sops.yaml`.

## Rotação pela CI

[.github/workflows/rotate-secrets.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/rotate-secrets.yml) roda por `workflow_dispatch`, com uma escolha de alvo (`sops-data-keys`, `cloudflare-tunnel-token`, `cloudflare-api-token` ou `all`) que decide quais dos jobs executam. Eles compartilham o mesmo environment `rotate-secrets`, e cada um termina abrindo um pull request em vez de fazer push em `main`, para que a rotação passe pelos mesmos gates que qualquer outra mudança. Não há agendamento nenhum nesse workflow, e é só por `workflow_dispatch` que ele roda, porque uma rotação automática abriria pull requests que ninguém está esperando e que mexem justamente nos arquivos mais sensíveis do repositório.

O job `sops-data-keys` roda `sops rotate` em todo arquivo cifrado do repositório, o que troca a chave de dados sem mudar nenhum valor; ele decifra com uma identidade age dedicada à CI, guardada no secret `ROTATION_AGE_KEY` do environment, que precisa estar em `.sops.yaml` como mais um destinatário, distinta da identidade da Secure Enclave, que não sai do Mac, e da chave de desastre, que não deveria sair do Bitwarden. Trocar só a chave de dados limita o estrago de uma chave exposta sem obrigar ninguém a decifrar e redigitar valor nenhum, e é por isso que esse job cabe na CI enquanto os outros não cabem. Como nenhum valor muda, o pull request resultante é grande e ilegível por natureza, e o que se revisa nele é que só arquivos cifrados foram tocados.

O job `cloudflare-tunnel-token` troca o segredo do túnel na Cloudflare e recifra o token novo no `SopsSecret` do cloudflared, com um token da Cloudflare restrito a Cloudflare Tunnel (`CLOUDFLARE_TUNNEL_TOKEN`). O job `cloudflare-api-token` rola o valor do API token do OpenTofu pela própria API da Cloudflare e o recifra em `tofu/cloudflare/cloudflare.sops.env`; para isso ele precisa de um token com permissão de editar tokens (`CLOUDFLARE_TOKENS_EDIT_TOKEN`), que é praticamente a conta inteira, o que o [desenho do OpenTofu](../arquitetura/opentofu.md) rejeitou para o próprio Tofu. Esse token existe só como secret do environment `rotate-secrets`, nunca num arquivo do repositório, o que restringe seu uso a esse workflow sem mudar o fato de ele ser poderoso demais para o dia a dia.

O que não cabe na CI de propósito: o segredo do webhook, os client secrets do Keycloak e o token de join do k3s precisam de acesso ao cluster ou ao node, e a API do k3s só aceita os CIDRs do operador; a passphrase do state exige recifrar todo state com o `fallback` do OpenTofu; e a chave age do node é rotacionada pelo Ansible. O que une esses casos é cada um exigir ou uma credencial que não deveria existir num runner do GitHub, ou uma sequência com revisão humana no meio. A chave age da CI, aliás, só decifra os arquivos do git; ela não é a chave do node e não abre nada de dentro do cluster.

## Prazos de rotação

O job `secret-age` da CI e `just lint-secret-age` leem a data `lastmodified` que o SOPS grava em cada arquivo cifrado e comparam com os prazos declarados arquivo por arquivo em `.config/secret-max-age.conf`. O prazo mais curto é o do `tofu/cloudflare/cloudflare.sops.env`. O mais longo cobre os segredos de infraestrutura mais sensíveis, como a passphrase do state, o `secrets.sops.yaml` do Ansible e o módulo `keycloak-master`. O restante dos arquivos com linha própria, como o token do túnel, fica num prazo intermediário, o mesmo da linha padrão `*`, que recolhe qualquer arquivo cifrado novo ainda sem linha dedicada.

Num push o job só anota um aviso; na execução agendada ele falha, o que deixa o workflow vermelho e faz o GitHub avisar por e-mail. A recipe local só relata, nunca falha. A diferença entre relatar e falhar está num único argumento, `--fail-on-stale`, que a CI passa apenas na execução agendada, de modo que o mesmo script serve de relatório e de gate sem duplicar a lógica dos prazos.

Limites reais vêm dessa escolha. O prazo é por arquivo, não por valor: trocar só o API token da Cloudflare zera também o relógio dos IDs, que moram no mesmo arquivo. E a data mede a última vez que o arquivo foi recifrado, não a última troca de valor: `just sops-rotate`, que troca só a chave de dados, zera a contagem sem o segredo ter mudado, enquanto `just sops-sync` sobre um arquivo já cifrado, que só atualiza destinatários, não mexe nela. Segredos fora do git, como o segredo do webhook, o PAT do Renovate e os certificados do k3s, não entram nessa conta.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
