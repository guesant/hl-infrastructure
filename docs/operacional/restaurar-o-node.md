# Restaurar o node do zero

<!-- source-of-trust paths=".sops.yaml .tools/sops-recipients.sh .tools/sops-drill.sh .tools/sops-sync.sh .tools/sops-rotate.sh" -->

Este runbook cobre a perda total do node: cartão SD corrompido, hardware trocado, ou um comprometimento em que a única resposta segura é reinstalar. O ponto de partida é um Raspberry Pi OS limpo com SSH por chave e acesso como root, exatamente como no [primeiro bootstrap](primeiro-bootstrap.md). A diferença está no que precisa ser recuperado de fora do git, listado em [estado fora do git](estado-fora-do-git.md).

## 1. Reconstruir o cluster

Na máquina do operador, `ansible/inventory.ini` continua válido se a máquina do operador sobreviveu; se não, recrie-o a partir do exemplo. `ansible/group_vars/all/secrets.sops.yaml` vem do próprio repositório, cifrado, e decifra com a identidade da Secure Enclave ou com a chave de recuperação.

Um node reinstalado tem host keys novas, e o `ansible/known_hosts` antigo faz o Ansible recusar a conexão, de propósito. Confira as impressões digitais novas no console do Pi e grave o arquivo de novo, como no [primeiro bootstrap](primeiro-bootstrap.md), antes de seguir:

```bash
ssh-keyscan <IP do Pi> | tee ansible/known_hosts | ssh-keygen -lf -
```

```bash
just preflight
just bootstrap-check
just bootstrap
```

Ao fim, `ansible/kubeconfig` aponta para o cluster novo e `kubectl -n argocd get applications` mostra o `root` sincronizando os satélites. O k3s reinstalado recebe o token declarado em `k3s_join_token`, o mesmo que o node antigo usava, então nada precisa ser recuperado nem regravado: o valor nunca deixou de existir, porque sempre foi o git quem o guardava.

A imagem do Raspberry Pi OS cria de novo o usuário padrão (`user`, uid 1000), com senha, grupo `sudo`, chave SSH e login automático tanto no desktop gráfico quanto no console `tty1`. Nada do cluster usa esse usuário, e o Ansible não o remove, então o passo é manual, por SSH como root, depois de confirmar que o `authorized_keys` do root tem a chave do operador:

```bash
systemctl set-default multi-user.target
systemctl disable --now lightdm
rm -rf /etc/systemd/system/getty@tty1.service.d && systemctl daemon-reload && systemctl restart getty@tty1
loginctl terminate-user user; userdel -r -f user
```

Não use `pkill -u user` nem espere o `userdel` sem `-f` passar: vários contêineres do cluster rodam com uid 1000, o mesmo número do usuário da imagem, então o `pkill` derruba pods de operadores e o `userdel` sempre encontra processos com esse uid. O `-f` só remove a conta e a home; os contêineres continuam rodando com o número de uid, que não depende da entrada em `/etc/passwd`.

Depois disso não existe login pelo console local: o root continua com a senha bloqueada e só entra por SSH com chave. Perder o SSH passa a significar tirar o disco e corrigi-lo em outra máquina.

O túnel e o DNS da Cloudflare não fazem parte desta reconstrução: eles vivem na conta da Cloudflare, não no node, e continuam existindo. O cloudflared volta sozinho quando o Argo sincroniza o satélite do blog, com o token que já está no `SopsSecret`, desde que o passo 2 abaixo deixe a chave do node nova capaz de decifrá-lo. Nenhum `just tofu` é necessário aqui.

O Keycloak, ao contrário, nasce vazio num node novo: o operator cria uma instância com um novo `temp-admin`, e nenhum realm existe. Os três states dos módulos `tofu/keycloak-*` ainda apontam para os IDs da instância antiga, então o caminho é o do primeiro bootstrap, precedido de um `state rm` ou de um novo `init` num state vazio: `just tofu keycloak-master apply` recria os realms, o `admin` e as contas de serviço, os outros dois módulos recriam o conteúdo, `just keycloak-bootstrap-admin` aposenta o `temp-admin` novo, e `just keycloak-user` recria os seus usuários, cujas senhas e TOTP se perderam com o banco. Os client secrets não mudam, porque vivem nos `SopsSecret`, então Grafana, Argo CD, Portainer, oauth2-proxy e o blog voltam a autenticar sem nenhuma alteração.

## 2. Confirmar a chave age

Um node novo não herda a chave age do node antigo: a role `sops_age_key` só gera uma chave quando o `Secret` `sops-age-key-file` ainda não existe, e num node recém-instalado ele nunca existe. O `bootstrap` do passo 1 gera uma chave nova, diferente da anterior. Enquanto isso não é corrigido, todo `SopsSecret` commitado continua decifrável pelas outras chaves listadas em `.sops.yaml` (a de rotina do operador na Secure Enclave, a de desastre no Bitwarden, ou qualquer outra que tenha sido adicionada), então este passo não é urgente, mas precisa ser feito antes de encerrar a reconstrução:

```bash
just sops-recipients sync-node
```

O comando lê a chave pública do node vivo e reescreve só a entrada rotulada `node` em `.sops.yaml` (o rótulo é o padrão de `sync-node`; passe outro se este cluster convive com mais de um node no mesmo `.sops.yaml`), sem tocar nas outras; revise o diff e commite. Rode `just sops-sync` em seguida para recifrar todo `SopsSecret` já commitado para os destinatários atuais; ele só pede `SOPS_AGE_KEY_FILE` se algum arquivo realmente precisar decifrar pra resincronizar, então tê-lo à mão (a chave de rotina do operador ou a de desastre) só importa se esse for o caso. Sem esse passo, os SopsSecret continuam decifráveis pelas chaves que não mudaram, só não estão recifrados para a chave nova do node até a próxima vez que alguém os editar. O gate `security-sopssecrets` (`just check`, e o job de mesmo nome na CI) deixa esse atraso visível: ele falha assim que os destinatários de algum `SopsSecret` divergirem do `.sops.yaml` atual, então um push sem o `sops-sync` correspondente não passa despercebido.

Se as outras chaves também se perderam junto com o Mac do operador, não há como recuperar o que já estava cifrado: gere um par novo com `just age-se-keygen` (ou um par de desastre novo com `just age-keygen`), adicione o destinatário em `.sops.yaml` com `just sops-recipients add <rótulo> <pública>` (ou `update <rótulo> <pública>` se o rótulo antigo ainda existir), e recifre cada `SopsSecret` de cada satélite a partir do valor original:

```bash
just sops-sync <caminho-do-sops-secret-em-texto-claro>
```

O valor original de cada segredo só existe onde o satélite o gerou (o token do túnel no painel da Cloudflare, as chaves do bucket no provedor). Commite os `SopsSecret` recifrados nos satélites; o Argo aplica no próximo ciclo.

## 3. O Postgres não tem backup hoje

O `Cluster` do CNPG no satélite do blog sobe vazio, com um banco novo e vazio: o backup contínuo em object storage foi desligado de propósito, e o operador `cnpg-barman-plugin` que o fazia funcionar nem está instalado hoje. Não há `ObjectStore` nem `ScheduledBackup` declarados, então não existe `bootstrap.recovery` possível; os dados que estavam no volume do node perdido não são recuperáveis por este runbook. Se o backup for religado no futuro, este passo volta a valer o formato de referência de recuperação do CNPG (`bootstrap.recovery` com um `externalClusters` apontando para o `ObjectStore`), e esta seção deve ser reescrita para descrevê-lo de novo.

## 4. Conferir

Passe pelo [checklist operacional](checklist.md) inteiro. Os itens de SSH, firewall e API são os que mais importam aqui, porque a máquina é nova e nenhuma regra foi conferida nela ainda.

## Continue por aqui

O [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) explica quais cenários terminam neste runbook.
