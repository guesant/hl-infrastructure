# Estado fora do git

Nem tudo que o cluster precisa está versionado, e o que não está precisa ser listado num lugar só, senão vira conhecimento tribal. Esta página é esse lugar: cada item diz onde vive, quem o cria e o que acontece se for perdido.

| Item | Onde vive | Quem cria | Se perdido |
| --- | --- | --- | --- |
| `ansible/group_vars/all/secrets.yml` | máquina do operador, ignorado pelo git | o operador, a partir de `secrets.example.yml` | reescrever a partir do exemplo; o segredo do webhook do Argo e a chave SSH precisam ser regenerados. As versões não estão aqui: `versions.yml` é versionado |
| `ansible/inventory.ini` | máquina do operador, ignorado pelo git | o operador, a partir de `inventory.example.ini` | reescrever; só contém o endereço do nó |
| `ansible/kubeconfig` | máquina do operador, ignorado pelo git | a role `k3s` no bootstrap | rodar `just bootstrap` de novo, que o busca do nó |
| `sealed-secrets-cert.pem` | máquina do operador, ignorado pelo git | `just fetch-cert` | rodar `just fetch-cert` de novo; é só a chave pública |
| chave privada do Sealed Secrets | `Secret` em `kube-system` no cluster | o controller, na primeira subida | todo `SealedSecret` de todo satélite precisa ser selado de novo com a chave nova |
| chave SSH de root do nó | `/root/.ssh/authorized_keys` no nó | a role `ssh_hardening`, a partir de `ssh_root_authorized_key` | acesso ao nó só pelo console do hipervisor |
| token do Renovate | environment `renovate` do repositório no GitHub | o operador, como PAT com escopo de escrita no repositório | o workflow `renovate` falha até um token novo ser cadastrado |
| segredos dos satélites | `SealedSecret` no repositório de cada satélite | cada satélite, com `just seal` | dependem da chave privada acima; o valor original só existe onde o satélite o gerou |
| dados do Postgres do blog | volume no nó, com backup em object storage pelo barman-cloud | o CloudNativePG | restaurar do último backup pelo próprio operador CNPG |
| o sistema operacional do nó | instalado pelo hipervisor ou pela imagem cloud | fora deste repositório | reinstalar e rodar `just bootstrap`; as roles de SO assumem Debian |

O critério para algo estar nesta lista é simples: se apagar o repositório e a máquina do operador não fosse suficiente para perder o item, ele não precisa estar aqui. Tudo o que está aqui precisa de uma cópia ou de um caminho de regeneração fora do git, e a coluna da direita é esse caminho.

## Continue por aqui

O [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) explica por que cada um desses itens é um ativo e o que os protege.
