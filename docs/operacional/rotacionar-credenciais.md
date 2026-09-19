# Rotacionar credenciais

Cada credencial abaixo tem rotina de rotação própria. Os certificados e o token de join do k3s vivem no node, cada um num playbook separado, e interrompem o cluster por alguns segundos; a chave age do sops-secrets-operator também vive lá, mas não interrompe nada, embora precise do passo extra de resincronizar os destinatários do SOPS.

O token do túnel do blog e o token de API que o OpenTofu usa vivem na Cloudflare. Nenhuma delas deve mudar como efeito colateral de um bootstrap ou de uma aplicação do OpenTofu.

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

O cert-manager percebe a ausência do segredo da CA, emite outro pelo emissor autoassinado e, com o certificado do domínio também apagado, reemite o certificado curinga assinado pela CA nova; o Traefik recarrega sozinho.

O passo que não é automático fica do lado dos dispositivos: cada um precisa confiar a CA nova, com a saída de `just internal-ca`, e remover a anterior. Sem rotação deliberada, a CA tem validade longa e mantém a chave ao renovar, para esse passo manual acontecer uma vez só.

## Token de join

```bash
just rotate-token
```

O git é a fonte do valor, não o node: a variável abaixo, cifrada no arquivo de segredos do Ansible, é o token que a [role do k3s](../arquitetura/ansible.md) grava no node em toda instalação nova, e é para ele que a recipe de rotação converge um node já vivo. Não existe cópia de recuperação separada, então também não existe cópia desatualizada para esquecer de atualizar.

Tratar o git como origem tem um custo assumido: o valor gravado no node e o valor declarado podem divergir sem ninguém notar, e é essa playbook, não o bootstrap, que reconcilia os dois.

| Variável | Onde |
| --- | --- |
| `k3s_join_token` | `ansible/group_vars/all/secrets.sops.yaml`; espelhado em `config.yaml` no node |

Para trocar, gere um valor novo com `openssl rand -hex 32` e grave-o na variável da tabela acima, editando o arquivo cifrado; só então rode a recipe de rotação. A playbook lê o token atual do node e o compara com o valor declarado: se forem diferentes, ela rotaciona o token no k3s, reescreve o arquivo de configuração e reinicia; se já forem iguais, não faz nada.

Antes de qualquer uma dessas coisas ela recusa continuar caso o valor declarado tenha menos de 32 caracteres, para uma edição interrompida do arquivo cifrado não virar um token fraco no node.

A reescrita do arquivo de configuração antes do restart não é detalhe. O k3s cifra os dados de bootstrap do datastore com o token do servidor, então um arquivo que ainda dissesse o token antigo faria o k3s subir sem conseguir decifrar o próprio datastore.

A reescrita usa o mesmo template `config.yaml.j2` da role do k3s, e não uma edição pontual da linha do token, de modo que o arquivo resultante é idêntico ao que um bootstrap produziria.

Num cluster de um nó só ninguém usa o token depois da instalação, então rotacioná-lo custa só o restart. Vale fazer se o node foi clonado ou se o token apareceu em algum log. A playbook não devolve o controle antes de o `/healthz` do API server voltar a responder, com até cinco minutos de tentativas, então o fim do comando já é o cluster de pé de novo.

## Chave age do node

Essa é a chave que o sops-secrets-operator usa para decifrar todo segredo cifrado dentro do cluster; ela é gerada no próprio node e a metade pública dela é um dos destinatários do arquivo de configuração do SOPS. Rotacioná-la passa por etapas, porque o arquivo de destinatários e o segredo do node precisam ficar consistentes o tempo todo, nunca um sem o outro.

A sequência abaixo mantém as duas identidades válidas no meio do caminho e só descarta a antiga no fim:

```bash
just rotate-age-key
```

Isso gera uma identidade nova, **acrescenta** ela ao arquivo de chaves do segredo do node (a antiga continua lá) e reinicia o sops-secrets-operator; nenhum segredo cifrado para de decifrar nesse meio-tempo, porque o age tenta cada identidade do arquivo até uma funcionar.

A recipe recria o segredo `sops-age-key-file` inteiro a partir do arquivo resultante, espera o rollout do operador terminar antes de devolver o controle, e imprime no fim a chave pública atual junto com os passos que ainda faltam. Em seguida:

```bash
just sops-recipients sync-node
just sops-sync
```

O primeiro escreve a chave pública nova no arquivo de destinatários do SOPS; revise o diff e commite. O segundo recifra todo segredo já commitado para os destinatários atuais. Só depois disso, com a chave nova já sendo a única referenciada ali e todo segredo já recifrado, feche a rotação removendo a identidade antiga:

```bash
just rotate-age-key -e sops_age_key_prune=true
```

Rodar a recipe de rotação sem a variável de novo, antes de prunar a antiga, só adiciona mais uma identidade; nada quebra, mas também não avança a rotação sozinho. O prune não escolhe qual identidade fica: ele mantém o bloco mais recente do arquivo de chaves, isto é, a identidade gerada por último.

É daí que vem a ordem exigida acima: prunar antes de sincronizar os segredos deixaria o operador sem a única identidade capaz de abrir os segredos ainda cifrados para a chave antiga.

## Token do túnel Cloudflare

O token do túnel não passa pelo OpenTofu: o módulo da Cloudflare cria o túnel, e o token é buscado depois pela API, com o id lido da saída do módulo e gravado direto no segredo do cloudflared, sem nunca entrar no state. Os dois passos são separados por consequência disso: a API devolve sempre o token atual, e sem rotacionar antes a recipe não teria nada novo para gravar.

Rotacione o token no dashboard, em Networking, Tunnels, o túnel do blog, Rotate token, e depois traga o novo para o segredo cifrado:

```bash
just cloudflare-tunnel-token
```

Commite e faça push. O cloudflared que já está rodando continua conectado com o token antigo até reiniciar, porque a rotação só impede conexões novas; o blog não cai entre a rotação e o sync. Quando o Argo aplicar o segredo novo, reinicie o Deployment do cloudflared para ele passar a usar o token novo, e lembre que rodar a recipe do token sem ter rotacionado nada no dashboard não muda o arquivo:

```bash
kubectl -n blog rollout restart deployment/cloudflared
```

Se o motivo da rotação é um token vazado, não espere: derrube também as conexões existentes pela API da Cloudflare antes do push, senão quem tem o token antigo continua conectado. É o inverso do parágrafo anterior, porque a propriedade que evita indisponibilidade numa rotação de rotina é a mesma que mantém um atacante ligado ao túnel. O blog sai do ar entre derrubar as conexões e o cloudflared novo subir, e nesse cenário esse é o custo certo.

## API token da Cloudflare e passphrase do state

O token de API não tem rotina automática. Crie um token novo no dashboard com as mesmas permissões, troque o valor no arquivo de segredos do módulo, confirme com um planejamento que nada muda, e só então revogue o antigo no dashboard:

```bash
just sops-edit tofu/cloudflare/cloudflare.sops.env
just tofu cloudflare plan
```

O planejamento no meio da sequência não é formalidade: ele prova que o token novo enxerga os mesmos recursos que o antigo, já que um escopo menor apareceria como erro de autorização ou como um recurso que o módulo acha que precisa recriar.

A passphrase do state é comum a todo módulo, e é ela que cifra os `terraform.tfstate` commitados, de modo que o OpenTofu só lê um state com a mesma chave que o gravou. A troca passa por todos os módulos por isso, e o script se recusa a gerar uma passphrase do zero enquanto existir algum `terraform.tfstate` no repositório, que ficaria ilegível. O caminho para trocar uma que já está em uso é outro:

```bash
just tofu-state-passphrase --rotate
```

Isso gera uma passphrase nova e guarda a atual como uma variável secundária, no mesmo arquivo cifrado, sem nenhuma delas passar pelo terminal. Em cada módulo, declare a variável correspondente e acrescente ao bloco de cifragem mais um provedor de chave com ela, referenciado num bloco de fallback dentro do state e do plan, conforme a tabela abaixo.

Rode a aplicação em cada módulo, sem mudança de recurso: o OpenTofu lê o state com a antiga e o grava com a nova. Por fim:

| Peça | Nome |
| --- | --- |
| Variável da passphrase anterior | `TF_VAR_state_passphrase_previous` |
| Declaração no módulo | `variable "state_passphrase_previous"` |
| Bloco de cifragem | `encryption.tf` |
| Provedor de chave adicional | `key_provider "pbkdf2"` |
| Bloco que referencia o provedor | `fallback` dentro de `state` e `plan` |

```bash
just tofu-state-passphrase --finish-rotation
```

Remova o bloco de fallback e a variável de cada módulo e commite os states regravados junto com o arquivo cifrado. Esse último comando reescreve o arquivo de passphrase só com a nova, então qualquer state que ainda estivesse cifrado com a antiga fica ilegível a partir dali. O script protege as duas pontas da sequência: ele recusa iniciar outra rotação enquanto a variável da passphrase anterior existir no arquivo, e recusa finalizar quando não há rotação em curso.

## Segredos do realm do Keycloak

A senha e o TOTP dos usuários dos realms vivem só no Keycloak e são trocados na conta de cada um (`/realms/<realm>/account`) ou, se perdidos, redefinidos com `just keycloak-user <realm> <usuário>`, que reaplica senha temporária e pertenças sem duplicar nada. Nada disso tem cópia no repositório, de propósito, e não há provedor de identidade externo de onde restaurar essas contas. Perder o volume do Postgres do Keycloak, num desastre, significa recriar cada usuário à mão.

A senha do administrador do master é a única credencial humana do Keycloak que vive no repositório, e só o OpenTofu a usa. A recipe de rotação do administrador gera uma senha nova, aplica pela API, confirma o login com ela, recifra o arquivo de segredos do módulo e confere que o planejamento continua vazio.

Commite o arquivo em seguida. Ela vive só nesse arquivo, então mudá-la à mão e aplicar o módulo também é uma rotação válida, só sem a confirmação que a recipe faz.

Um client secret vive num lugar só, o segredo cifrado que o consumidor monta, listados na tabela abaixo. O módulo do realm o lê dali por um mapa próprio, então a rotação é editar esse arquivo, aplicar o módulo correspondente e dar push. O consumidor recebe o segredo novo pelo sops-secrets-operator, o Reloader reinicia quem lê por variável de ambiente, e o Keycloak passa a aceitar o novo valor na mesma aplicação.

| Consumidor | Onde o secret é montado |
| --- | --- |
| `argocd`, `grafana` | segredo `sso` |
| `oauth2-proxy`, `portainer`, `blog` | segredo do próprio chart |

As contas de serviço dos módulos management e homelab são declaradas no arquivo de segredos do master e lidas de lá pelos outros módulos, então rotacioná-las é mudar o valor ali e aplicar o master antes dos outros. Aplicar fora dessa ordem falha de um jeito claro, porque os outros dois módulos autenticam no Keycloak justamente com esses segredos.

É também a razão de o master ser o único módulo do Keycloak com arquivo cifrado próprio: ele guarda credenciais que pertencem ao Keycloak, não a um consumidor.

## Segredo do webhook do GitHub

O segredo que o GitHub usa para assinar os eventos de push enviados ao Argo CD mora cifrado no arquivo de segredos do Ansible, e existe em mais lugares, listados na tabela abaixo. Todos precisam bater. Enquanto não batem, o Argo recusa a assinatura e volta a descobrir commits só pelo polling periódico, sem quebrar nada.

| Onde vive | Identificador |
| --- | --- |
| Arquivo de segredos do Ansible | `argocd_github_webhook_secret` |
| Segredo do ArgoCD no cluster | `argocd-secret`, chave `webhook.github.secret` |
| GitHub | configuração do webhook do repositório |

Gere o valor e grave-o sem que ele passe pela tela nem pela linha de comando. Os comandos abaixo cobrem duas dessas pontas de uma vez, o arquivo cifrado e a configuração do webhook no GitHub, para elas não ficarem divergentes entre um passo e outro. O valor só existe numa variável do shell, descartada no fim:

```bash
new="$(openssl rand -hex 32)"
printf '"%s"' "$new" | SOPS_AGE_KEY_FILE=~/.config/hl-infrastructure/sops/operator-se.txt sops set --value-stdin ansible/group_vars/all/secrets.sops.yaml '["argocd_github_webhook_secret"]'
printf '{"config":{"url":"https://ops.guesant.net/api/webhook","content_type":"json","insecure_ssl":"0","secret":"%s"}}' "$new" | gh api -X PATCH repos/guesant/hl-infrastructure/hooks/<id> --input -
unset new
```

O id do webhook sai de uma consulta à API do GitHub aos hooks do repositório. Para configurar o webhook à mão pela interface do GitHub, em vez da API, a recipe abaixo copia o valor atual decifrado para a área de transferência sem mostrá-lo na tela; sem o utilitário de recorte, ela apenas o imprime:

```bash
just webhook-secret | pbcopy
```

A listagem da API traz também a URL de cada hook, o que basta para saber qual id é o do Argo quando existe mais de um configurado.

Falta levar o valor novo ao cluster. O bootstrap grava o valor no segredo do ArgoCD: a role dele compara o que está no cluster com o valor cifrado e só reaplica quando eles diferem, e o servidor do Argo lê a mudança sem reiniciar. Confira pela API do GitHub que a entrega seguinte do evento de push voltou com status 200, e commite o arquivo de segredos.

## Rotação pela CI

O [workflow de rotação de segredos](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/rotate-secrets.yml) roda por acionamento manual (`workflow_dispatch`), com uma escolha de alvo que decide quais dos jobs executam, listados na tabela abaixo. Eles compartilham o mesmo ambiente de execução, e cada um termina abrindo um pull request em vez de fazer push direto, para a rotação passar pelos mesmos gates de qualquer outra mudança.

Não há agendamento nenhum nesse workflow, porque uma rotação automática abriria pull requests que ninguém está esperando, mexendo justamente nos arquivos mais sensíveis do repositório.

| Alvo | Job faz o quê | Secret do ambiente |
| --- | --- | --- |
| `sops-data-keys` | troca a chave de dados de todo segredo cifrado | `ROTATION_AGE_KEY` |
| `cloudflare-tunnel-token` | troca o token do túnel do blog | `CLOUDFLARE_TUNNEL_TOKEN` |
| `cloudflare-api-token` | rola o token de API que o OpenTofu usa | `CLOUDFLARE_TOKENS_EDIT_TOKEN` |
| `all` | roda os três jobs acima | nenhum |

O job de chaves de dados decifra com uma identidade age dedicada à CI, que precisa estar no arquivo de destinatários como mais um deles, distinta da identidade da Secure Enclave, que não sai do Mac, e da chave de desastre, que não deveria sair do Bitwarden.

Trocar só a chave de dados limita o estrago de uma chave exposta sem obrigar ninguém a decifrar e redigitar valor nenhum, e é por isso que esse job cabe na CI enquanto os outros não cabem.

Como nenhum valor muda nessa rotação, o pull request resultante é grande e ilegível por natureza, e o que se revisa nele é só que os arquivos tocados continuam cifrados. Os dois jobs da Cloudflare, em contraste, trocam um valor de verdade: o do túnel recifra o segredo do cloudflared, e o de API recifra o arquivo de segredos do módulo.

O token do job de API é praticamente a conta inteira, permissão que o [desenho do OpenTofu](../arquitetura/opentofu.md) rejeitou para o próprio Tofu. Ele existe só como secret do ambiente de execução, nunca num arquivo do repositório, o que restringe seu uso a esse workflow sem mudar o fato de ele ser poderoso demais para o dia a dia.

O que não cabe na CI de propósito: o segredo do webhook, os client secrets do Keycloak e o token de join do k3s precisam de acesso ao cluster ou ao node, e a API do k3s só aceita os CIDRs do operador; a passphrase do state exige recifrar todo state com o fallback do OpenTofu; e a chave age do node é rotacionada pelo Ansible.

O que une esses casos é cada um exigir ou uma credencial que não deveria existir num runner do GitHub, ou uma sequência com revisão humana no meio. A chave age da CI, aliás, só decifra os arquivos do git; ela não é a chave do node e não abre nada de dentro do cluster.

## Prazos de rotação

O job de idade dos segredos na CI e a recipe equivalente local leem a data `lastmodified` que o SOPS grava em cada arquivo cifrado e comparam com os prazos declarados arquivo por arquivo num arquivo de configuração. O prazo mais curto é o do arquivo de segredos da Cloudflare.

O mais longo cobre os segredos de infraestrutura mais sensíveis, como a passphrase do state, o arquivo de segredos do Ansible e o módulo master do Keycloak. O restante dos arquivos com linha própria, como o token do túnel, fica num prazo intermediário, o mesmo da linha padrão, que recolhe qualquer arquivo cifrado novo ainda sem linha dedicada.

Num push o job só anota um aviso; na execução agendada ele falha, o que deixa o workflow vermelho e faz o GitHub avisar por e-mail. A recipe local só relata, nunca falha. A diferença entre relatar e falhar está num único argumento, `--fail-on-stale`, que a CI passa apenas na execução agendada, de modo que o mesmo script serve de relatório e de gate sem duplicar a lógica dos prazos.

Limites reais vêm dessa escolha. O prazo é por arquivo, não por valor: trocar só o token de API da Cloudflare zera também o relógio dos IDs, que moram no mesmo arquivo.

A data também mede a última vez que o arquivo foi recifrado, não a última troca de valor: a rotação que troca só a chave de dados zera a contagem sem o segredo ter mudado, enquanto sincronizar destinatários sobre um arquivo já cifrado não mexe nela. Segredos fora do git, como o segredo do webhook, o PAT do Renovate e os certificados do k3s, não entram nessa conta.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
