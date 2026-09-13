# Estado fora do git

Nem tudo que o cluster precisa está versionado, e o que não está precisa ser listado num lugar só, senão vira conhecimento tribal. Esta página é esse lugar: cada item diz onde vive, quem o cria e o que acontece se for perdido.

| Item | Onde vive | Quem cria | Se perdido |
| --- | --- | --- | --- |
| `ansible/group_vars/all/secrets.yml` | máquina do operador, ignorado pelo git | o operador, a partir de `secrets.example.yml` | reescrever a partir do exemplo; o segredo do webhook do Argo e a chave SSH precisam ser regenerados. As versões não estão aqui: `versions.yml` é versionado |
| `ansible/inventory.ini` | máquina do operador, ignorado pelo git | o operador, a partir de `inventory.example.ini` | reescrever; só contém o endereço do nó |
| `ansible/kubeconfig` | máquina do operador, ignorado pelo git | a role `k3s` no bootstrap | rodar `just bootstrap` de novo, que o busca do nó |
| chave privada do Sealed Secrets | `Secret` em `kube-system` no cluster | o controller, na primeira subida | todo `SealedSecret` de todo satélite precisa ser selado de novo com a chave nova, e `sealed-secrets-cert.pem` precisa ser buscado e commitado de novo com `just fetch-cert` |
| chave SSH de root do nó | `/root/.ssh/authorized_keys` no nó | a role `ssh_hardening`, a partir de `ssh_root_authorized_key` | acesso ao nó só pelo console do hipervisor |
| token do Renovate | environment `renovate` do repositório no GitHub | o operador, como PAT com escopo de escrita no repositório | o workflow `renovate` falha até um token novo ser cadastrado |
| segredos dos satélites | `SealedSecret` no repositório de cada satélite | cada satélite, com `just seal` | dependem da chave privada acima; o valor original só existe onde o satélite o gerou |
| dados do Postgres do blog | volume no nó, com backup em object storage pelo barman-cloud | o CloudNativePG | restaurar do último backup pelo próprio operador CNPG |
| o sistema operacional do nó | instalado pelo hipervisor ou pela imagem cloud | fora deste repositório | reinstalar e rodar `just bootstrap`; as roles de SO assumem Debian |

`sealed-secrets-cert.pem`, a chave pública do Sealed Secrets, não entra nesta lista de propósito: ela é commitada no repositório. Um `SealedSecret` só pode ser cifrado com a chave pública, nunca decifrado com ela, então commitá-la não expõe nenhum segredo; é o que permite selar um segredo novo sem precisar de acesso ao cluster, só com `just seal`.

O critério para algo estar nesta lista é simples: se apagar o repositório e a máquina do operador não fosse suficiente para perder o item, ele não precisa estar aqui. Tudo o que está aqui precisa de uma cópia ou de um caminho de regeneração fora do git, e a coluna da direita é esse caminho.

## Capturar uma mudança manual de volta para o git

Se uma mudança acabou aplicada direto no cluster, fora do fluxo normal de GitOps (por exemplo, um `kubectl edit` de emergência), ela não deveria ficar assim: uma `Application` com sincronização automática reverte esse tipo de mudança na próxima reconciliação, e mesmo sem `selfHeal` ligado a mudança vive só na memória de quem a aplicou, sem sobreviver a uma reconstrução do node. `.tools/freeze-manifest.sh` existe para esse resgate: ele roda `kubectl get <kind> <nome> -o json`, remove os campos que só fazem sentido num objeto vivo (`resourceVersion`, `generation`, `managedFields`, `uid`, `.status`, entre outros) e produz um YAML limpo, pronto para commitar no lugar certo do repositório ou do satélite.

```bash
.tools/freeze-manifest.sh <kind> <nome> -n <namespace> > caminho/do/manifesto.yaml
```

Depois de commitado, o Argo passa a rastrear esse objeto como qualquer outro: a mudança que antes só existia no cluster agora tem uma origem no git, e uma reconstrução do node a partir do zero a recria sem depender de ninguém lembrar que ela existia.

## Continue por aqui

O [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) explica por que cada um desses itens é um ativo e o que os protege.
