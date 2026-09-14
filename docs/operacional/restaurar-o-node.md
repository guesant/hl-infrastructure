# Restaurar o node do zero

<!-- source-of-trust paths=".sops.yaml .tools/sops-recipients.sh .tools/sops-drill.sh .tools/sops-sync.sh .tools/sops-rotate.sh" -->

Este runbook cobre a perda total do node: cartão SD corrompido, hardware trocado, ou um comprometimento em que a única resposta segura é reinstalar. O ponto de partida é um Raspberry Pi OS limpo com SSH por chave e um usuário com `sudo`, exatamente como no [primeiro bootstrap](primeiro-bootstrap.md). A diferença está no que precisa ser recuperado de fora do git, listado em [estado fora do git](estado-fora-do-git.md).

## 1. Reconstruir o cluster

Na máquina do operador, `ansible/inventory.ini` e `ansible/group_vars/all/secrets.yml` continuam válidos se a máquina do operador sobreviveu; se não, recrie os dois a partir dos exemplos, com um segredo de webhook novo (o antigo está perdido junto com o cluster, e o webhook no GitHub precisa ser atualizado).

```bash
just preflight -K
just bootstrap-check -K
just bootstrap -K
```

Ao fim, `ansible/kubeconfig` aponta para o cluster novo e `kubectl -n argocd get applications` mostra o `root` sincronizando os satélites.

## 2. Confirmar a chave age

Um node novo não herda a chave age do node antigo: a role `sops_age_key` só gera uma chave quando o `Secret` `sops-age-key-file` ainda não existe, e num node recém-instalado ele nunca existe. O `bootstrap` do passo 1 gera uma chave nova, diferente da anterior. Enquanto isso não é corrigido, todo `SopsSecret` commitado continua decifrável pelas outras chaves listadas em `.sops.yaml` (a de rotina do operador na Secure Enclave, a de desastre no Bitwarden, ou qualquer outra que tenha sido adicionada), então este passo não é urgente, mas precisa ser feito antes de encerrar a reconstrução:

```bash
just sops-recipients sync-node
```

O comando lê a chave pública do node vivo e reescreve só a entrada rotulada `node` em `.sops.yaml` (o rótulo é o padrão de `sync-node`; passe outro se este cluster convive com mais de um node no mesmo `.sops.yaml`), sem tocar nas outras; revise o diff e commite. Rode `just sops-sync` em seguida para recifrar todo `SopsSecret` já commitado para os destinatários atuais; ele só pede `SOPS_AGE_KEY_FILE` se algum arquivo realmente precisar decifrar pra resincronizar, então tê-lo à mão (a chave de rotina do operador ou a de desastre) só importa se esse for o caso. Sem esse passo, os SopsSecret continuam decifráveis pelas chaves que não mudaram, só não estão recifrados para a chave nova do node até a próxima vez que alguém os editar. O gate `security-sopssecrets` (`just check`, e o job de mesmo nome na CI) deixa esse atraso visível: ele falha assim que os destinatários de algum `SopsSecret` divergirem do `.sops.yaml` atual, então um push sem o `sops-sync` correspondente não passa despercebido.

Se as outras chaves também se perderam junto com o Mac do operador, não há como recuperar o que já estava cifrado: gere um par novo com `just age-se-keygen` (ou um par de desastre novo com `just age-keygen`), adicione o destinatário em `.sops.yaml` com `just sops-recipients add <rótulo> <pública>` (ou `update <rótulo> <pública>` se o rótulo antigo ainda existir), e recifre cada `SopsSecret` de cada satélite a partir do valor original:

```bash
just sops-sync <caminho-do-sopssecret-em-texto-claro>
```

O valor original de cada segredo só existe onde o satélite o gerou (o token do túnel no painel da Cloudflare, as chaves do bucket no provedor). Commite os `SopsSecret` recifrados nos satélites; o Argo aplica no próximo ciclo.

## 3. Restaurar o Postgres

O `Cluster` do CNPG no satélite do blog sobe vazio. Para recuperar do último backup no object storage, o satélite declara temporariamente um `Cluster` novo com `bootstrap.recovery` apontando para o mesmo `ObjectStore`:

```yaml
spec:
  bootstrap:
    recovery:
      source: postgres-backup
  externalClusters:
    - name: postgres-backup
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: postgres-backup
          serverName: postgres
```

O operador reconstrói o banco a partir do último backup base mais os WALs arquivados, até o último ponto recuperável (`kubectl -n blog get cluster postgres -o jsonpath='{.status.firstRecoverabilityPoint}'` mostra desde quando há recuperação possível). Depois que o cluster está `Ready` com os dados, o `bootstrap.recovery` sai do manifesto e o `ScheduledBackup` volta a apontar para ele.

## 4. Conferir

Passe pelo [checklist operacional](checklist.md) inteiro. Os itens de SSH, firewall e API são os que mais importam aqui, porque a máquina é nova e nenhuma regra foi conferida nela ainda.

## Continue por aqui

O [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) explica quais cenários terminam neste runbook.
