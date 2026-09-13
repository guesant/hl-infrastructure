# Restaurar o node do zero

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

Um node novo não herda a chave age do node antigo: a role `sops_age_key` só gera uma chave quando o `Secret` `sops-age-key-file` ainda não existe, e num node recém-instalado ele nunca existe. O `bootstrap` do passo 1 gera uma chave nova, diferente da anterior, e imprime a metade pública no output (`ansible.builtin.debug`, procure por "Add this recipient to .sops.yaml").

É exatamente para este cenário que existe a segunda chave, a de backup, gerada com `just age-keygen` e guardada só no gerenciador de senhas do operador: como `.sops.yaml` já lista os dois destinatários, todo `SopsSecret` commitado continua decifrável pela chave de backup, mesmo com a chave do node tendo mudado. Nada precisa ser recifrado.

Se a chave de backup também se perdeu junto com a máquina do operador, não há como recuperar o que já estava cifrado: gere um par novo, adicione o destinatário em `.sops.yaml` no lugar do antigo, e recifre cada `SopsSecret` de cada satélite a partir do valor original:

```bash
just age-keygen
just sops-encrypt <caminho-do-sopssecret-em-texto-claro>
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
