# Estado fora do git

<!-- source-of-trust paths=".sops.yaml .tools/sops-recipients.sh .tools/sops-drill.sh .tools/sops-sync.sh .tools/sops-rotate.sh" -->

Nem tudo que o cluster precisa está versionado, e o que não está precisa ser listado num lugar só, senão vira conhecimento tribal. Esta página é esse lugar: cada item diz onde vive, quem o cria e o que acontece se for perdido. A última coluna é a que importa num incidente, porque é ela que separa o item que se regenera sozinho na próxima execução daquele cuja perda é definitiva.

| Item | Onde vive | Quem cria | Se perdido |
| --- | --- | --- | --- |
| `.local/operator/inventory.ini` | máquina do operador, ignorado pelo git | o operador, a partir de `inventory.example.ini` | reescrever; só contém o endereço do nó |
| `.local/operator/kubeconfig` | máquina do operador, ignorado pelo git | a role `k3s` no bootstrap | rodar `just bootstrap` de novo, que o busca do nó |
| `.local/operator/known_hosts` | máquina do operador, ignorado pelo git, porque traz o IP interno do node | o operador, com `ssh-keyscan` depois de conferir as impressões digitais | gerar de novo depois de conferir as chaves; o Ansible recusa conectar com `StrictHostKeyChecking=yes` enquanto ele faltar ou divergir, e uma reinstalação do node gera chaves novas que precisam ser conferidas antes |
| chave privada age do node | `Secret` `sops-age-key-file` no namespace `sops` | a role `sops_age_key`, com `age-keygen` direto no node, na primeira execução | perdida junto com o node; as outras chaves em `.sops.yaml` são o que evita perder acesso a todo `SopsSecret` junto com ela. A pública de um node vivo se recupera e é escrita em `.sops.yaml` a qualquer momento com `just sops-recipients sync-node`, sem depender de ter guardado o output do primeiro `bootstrap`; o rótulo é `node` por padrão, mas `sync-node <rótulo>` aceita qualquer outro |
| chave de cifragem de `Secret` do k3s | `/var/lib/rancher/k3s/server/cred/encryption-config.json` no node | o k3s, quando a role `k3s` liga `secrets-encryption` | perdida junto com o node, e sem consequência: todo `Secret` do cluster é recriado a partir de um `SopsSecret` ou pelo operador que o gerou, então um node novo gera uma chave nova e nada precisa ser recuperado |
| identidade age-plugin-se do operador | Secure Enclave do Mac do operador; o arquivo `~/.config/hl-infrastructure/sops/operator-se.txt` é só uma referência ao slot, mais uma cópia do seu conteúdo (`AGE-PLUGIN-SE-1...`) como nota segura no Bitwarden | o operador, com `just age-se-keygen` | o slot morre com o Mac; recriar o arquivo a partir da nota do Bitwarden no mesmo Mac recupera o acesso, porque o slot em si continua vivo. Se o Mac também se perdeu, só a chave de desastre abaixo decifra |
| chave privada age de desastre | Bitwarden, fora de qualquer máquina deste fluxo | o operador, com `just age-keygen` | nada muda: ela é redundância pura, as outras identidades continuam decifrando sozinhas. Só importa se as identidades acima se perderem juntas; `just sops-drill-dr` confere periodicamente que ela ainda decifra |
| chave privada SSH do operador | máquina do operador, referenciada por `ansible_ssh_private_key_file` em `inventory.ini` | o operador, fora deste repositório | acesso ao nó só pelo console do hipervisor; a chave pública correspondente precisa estar em `ansible/group_vars/all/authorized_keys.yml`, que é commitado, para o próximo bootstrap voltar a aceitá-la |
| token do Renovate | environment `renovate` do repositório no GitHub | o operador, como PAT com escopo de escrita no repositório | o workflow `renovate` falha até um token novo ser cadastrado |
| API token da Cloudflare | cifrado em `tofu/cloudflare/cloudflare.sops.env`; o original só existe no dashboard da Cloudflare | o operador, no dashboard, com Cloudflare Tunnel e DNS de edição | criar outro com as mesmas permissões e trocar com `just sops-edit`; nada no cluster depende dele, só o `just tofu cloudflare` |
| passphrase do state do OpenTofu | cifrada em `tofu/state.sops.env`, comum a todo módulo; nunca impressa nem gravada em outro lugar | `just tofu-state-passphrase`, no primeiro bootstrap | nenhum `terraform.tfstate` commitado abre mais; os recursos continuam no ar, e uma passphrase nova mais `tofu import` em cada módulo reconstrói os states |
| token do túnel Cloudflare | na Cloudflare, com cópia cifrada em `tunnel-token.sops-secret.yaml` do cloudflared | a Cloudflare, ao criar o túnel; copiado por `just cloudflare-tunnel-token` | rodar a recipe de novo; se ele vazou, rotacionar na Cloudflare antes |
| chave de autorização do Tailscale | cifrada em `ansible/group_vars/all/secrets.sops.yaml` (`tailscale_auth_key`); o original só existe no console de administração da tailnet | o operador, no console, como chave reutilizável de uso único | irrelevante depois que o node entrou na tailnet: a chave só serve para o primeiro `tailscale up`, e um node reinstalado precisa de uma nova, criada do mesmo jeito |
| OAuth client do Tailscale | cifrado em `tofu/tailscale/tailscale.sops.env`; o original só existe no console | o operador, no console, com escopo de DNS e leitura de dispositivos | criar outro e trocar com `just sops-edit`; nada no node depende dele, só o `just tofu tailscale` |
| expiração da chave do node na tailnet | console de administração da tailnet | o operador, desligando a expiração da chave do node em Machines, a menos que o node tenha entrado com uma tag | desligar de novo depois de uma reinstalação; enquanto a expiração estiver ligada, o node cai da tailnet quando a chave vence |
| chave privada da CA interna | `Secret` `internal-ca` no namespace `cert-manager` | o cert-manager, a partir do `ClusterIssuer` autoassinado declarado pelo ingress | o cert-manager gera outra CA e reemite o certificado dos nomes internos; cada dispositivo precisa confiar a CA nova com `just internal-ca` |
| confiança na CA interna | o repositório de autoridades de cada dispositivo do operador | o operador, instalando a saída de `just internal-ca` | avisos de certificado nos nomes internos até instalar de novo; nada no cluster muda |
| administrador temporário do Keycloak | `SopsSecret` `keycloak-bootstrap-admin` no namespace `keycloak`, só num cluster nascendo vazio, com a mesma credencial em `tofu/keycloak-master/keycloak-master.sops.env` | o operador, com `just sops-sync`, antes do primeiro `apply` do `master`; o Keycloak só o lê quando o realm `master` não tem usuário | irrelevante depois de `just keycloak-bootstrap-admin`, que apaga o usuário e aponta o módulo para o administrador permanente declarado no mesmo `.sops.env`; o `SopsSecret` pode sair do chart em seguida |
| usuários humanos dos realms do Keycloak (`master`, `homelab`, `management`) | só no banco do Keycloak, com senha e TOTP | o operador, com `just keycloak-user <realm> <usuário>`, que pede a senha temporária no terminal | recriar com a mesma recipe; o que o git garante é a regra (grupo `admins`, TOTP obrigatório), não as contas |
| senha do `admin` local do Grafana | `Secret` `kps-grafana`, gerado pelo chart, sem cópia | o chart, na primeira instalação | ninguém a usa: o formulário está desligado e o login é pelo Keycloak; o `admin` do Argo CD foi desativado de vez |
| espelho do provider `keycloak/keycloak` | `.cache/tofu/mirror`, ignorado pelo git | `.tools/tofu-mirror.sh`, chamado por todo `plan`, `apply` e pela CI | baixar de novo; o lock file commitado recusa um zip diferente do publicado |
| segredos dos satélites | `SopsSecret` no repositório de cada satélite | cada satélite, com `just sops-sync` | dependem de uma das chaves privadas listadas em `.sops.yaml`; o valor original só existe onde o satélite o gerou |
| reclaim `Retain` nos PVs do Postgres do blog e do Prometheus | nos objetos `PersistentVolume`, alterados à mão com `kubectl patch` porque nasceram na classe `local-path` do k3s com `Delete`; a classe nova é `Retain` e nenhum PV novo precisa disso | o operador, com `kubectl patch pv` | um PV recriado pelo provisioner novo já nasce `Retain`; se um deles for recriado, nada a fazer |
| volumes do Keycloak e do Portainer na classe `local-path-retain` | `PersistentVolumeClaim` com `storageClassName` imutável, apontando para uma classe que só existe no cluster (saiu do git) | a versão anterior do chart do Postgres do blog | recriar os PVCs na classe `local-path` (instance novo no CNPG, PVC novo no Portainer) e apagar a classe antiga; até lá ela fica |
| dados do Postgres do blog | só no volume do nó; o backup contínuo em object storage está desligado de propósito por enquanto | o CloudNativePG | nenhum: sem `ObjectStore`/`ScheduledBackup`, a perda do volume é perda total dos dados. Reinstalar o operador `cnpg-barman-plugin` e religar o backup no `Cluster` é o que devolve essa linha à categoria "recuperável" |
| credenciais PostgreSQL do blog e do Keycloak | Secrets A/B cifrados por SOPS em `argocd/apps/secrets/data/postgres` e cópias locais criadas pelo ESO | `just postgres-rotation-prepare`, seguido de ativação GitOps | preparar o slot inativo, testar a conexão, ativar, observar por 30 minutos e aposentar o slot anterior |
| o sistema operacional do nó | instalado pelo hipervisor ou pela imagem cloud | fora deste repositório | reinstalar e rodar `just bootstrap`; as roles de SO assumem Debian |

`.sops.yaml`, com os destinatários públicos age do sops-secrets-operator, não entra nesta lista de propósito: ele é commitado no repositório. Uma chave pública age só permite cifrar, nunca decifrar, então commitá-la não expõe nenhum segredo; é o que permite cifrar um segredo novo sem precisar de acesso ao cluster, só com a recipe de sincronização.

Quem quiser conferir quais identidades ainda decifram não precisa abrir o arquivo à mão: `just sops-recipients list` imprime os destinatários atuais com o rótulo de cada um, hoje três, node, operator-se e dr.

O gate de segredos cifrados garante que essa lista e o que está de fato cifrado em cada satélite nunca fiquem para trás um do outro. A recipe de rotação troca a DEK (a chave de conteúdo) de um segredo sem mudar quem consegue decifrar, útil como higiene periódica independente de qualquer rotação de destinatário.

Essa rotação precisa de `SOPS_AGE_KEY_FILE` apontando para uma identidade que decifre, já que trocar a chave de conteúdo passa por abrir o arquivo, e ela deixa de lado o que ainda está em texto claro em vez de cifrar por conta própria, que é trabalho da recipe de sincronização.

O critério para algo estar nesta lista é simples: se apagar o repositório e a máquina do operador não fosse suficiente para perder o item, ele não precisa estar aqui. Tudo o que está aqui precisa de uma cópia ou de um caminho de regeneração fora do git, e a coluna da direita é esse caminho.

O que nasce de um segredo cifrado commitado fica de fora por esse mesmo critério, mesmo existindo só dentro do cluster, porque o git já é a cópia dele.

## As pastas fora do git

Os arquivos fora do git que sobrevivem entre execuções caem em algumas pastas, cada uma com uma regra própria. A separação não é organização pela organização: é ela que permite a `just cleanup` rodar um `git clean -fdx` sem hesitar, porque o destino de cada arquivo já está decidido pela pasta em que ele está. Um arquivo solto na raiz não teria essa garantia.

`.local/operator/` guarda o que é da máquina do operador e não se regenera sozinho sem uma ação humana, os quatro arquivos da tabela abaixo, os mesmos itens no topo da tabela desta página.

| Arquivo | Origem |
| --- | --- |
| `inventory.ini` | copiado de `inventory.example.ini`, o único arquivo dessa pasta commitado, por exceção no `.gitignore` |
| `kubeconfig` | buscado do node pela role `k3s` numa execução nova do bootstrap |
| `.kubeconfig.fetched` | marcador de que o kubeconfig já foi buscado |
| `known_hosts` | gravado pelo operador com `ssh-keyscan` |

É por isso que a pasta inteira é a exceção mais larga da limpeza: apagar `known_hosts` obriga a conferir as impressões digitais do node de novo antes do próximo playbook, porque o Ansible recusa a conexão enquanto o arquivo faltar ou divergir. O kubeconfig é o único da pasta que volta sozinho.

`.cache/` guarda o oposto, artefato que só acelera uma execução futura e não tem valor nenhum de ser inspecionado: o cache de schema do kubeconform, o espelho de provider do OpenTofu, o cache de fatos do Ansible.

`.build/` guarda saída de build ou relatório feito para ser inspecionado por uma pessoa ou consumido por outra etapa de ferramenta: os manifestos renderizados dos charts Helm, os relatórios de SBOM do trivy, o relatório de duplicação do jscpd, o site estático do MkDocs. O critério entre elas é se alguém teria motivo para abrir o conteúdo depois de gerado, em vez de só deixar a ferramenta reaproveitá-lo na execução seguinte.

Um item novo que precise sobreviver a uma limpeza entra numa dessas pastas, nunca solto na raiz do repositório. Na raiz ele dependeria de alguém lembrar de acrescentá-lo à lista de exceções antes da próxima limpeza, e esse esquecimento só se manifesta depois da perda. As três pastas já carregam a decisão tomada: a do operador sobrevive inteira, e as de cache e de build são descartáveis por definição.

Duas recipes cuidam da limpeza, listadas na tabela abaixo, e a que apaga de verdade roda `git clean -fdx` com as exceções da segunda tabela.

| Recipe | Faz o quê |
| --- | --- |
| `just cleanup-dry-run` | mostra o que seria apagado, sem apagar nada |
| `just cleanup` | apaga de verdade |

| Exceção | Onde declarada |
| --- | --- |
| `.local/operator/` inteira | preservada explicitamente pela recipe |
| `*.agekey`, `keys.txt`, `sops-age-key.txt`, `operator-se.txt` | já protegidos pelo `.gitignore` |
| `PENDENCIAS.local.md` | variável `cleanup_excludes` do `justfile` |

A recipe destrutiva ainda pede confirmação no terminal antes de rodar, pelo atributo `[confirm]` do just, então o dry-run é conveniência para revisar a lista com calma, não a única rede de proteção.

## Onde ficam os arquivos cifrados

Os arquivos SOPS não moram numa pasta única, e isso é deliberado: cada um fica onde a ferramenta que o consome consegue lê-lo, listados na tabela abaixo.

| Onde vive | O quê | Por quê |
| --- | --- | --- |
| `argocd/apps/secrets/**/*.sops-secret.yaml` | `SopsSecret` | manifest YAML direto, lido pelo Argo CD e decifrado pelo operator no cluster |
| `ansible/group_vars/all/secrets.sops.yaml` | segredos do Ansible, cifrados | o vars plugin da `community.sops` só carrega variáveis dessas pastas |
| `ansible/group_vars/all/authorized_keys.yml` | chaves autorizadas, texto claro | chave pública não é segredo |
| `tofu/` | `.sops.env` do OpenTofu | ao lado dos módulos que o `tofu-run.sh` executa |

O token do k3s e as chaves autorizadas vivem juntos porque o Ansible já carrega variáveis desse mesmo diretório para todo o inventário.

Uma pasta `secrets/` central obrigaria o Argo e o Ansible a ler de fora da própria árvore. O que os une é a regra do arquivo de destinatários e os scripts de sync, rotação, drill e checagem, que procuram em todos esses caminhos.

Todos eles varrem os mesmos três lugares, os segredos do Argo dentro de `argocd/`, os arquivos de ambiente do OpenTofu dentro de `tofu/` e as variáveis do Ansible no diretório de variáveis de grupo, de modo que um arquivo cifrado criado fora dessa varredura escaparia calado do sync, da rotação e do drill.

## Capturar uma mudança manual de volta para o git

Se uma mudança acabou aplicada direto no cluster, fora do fluxo normal de GitOps (por exemplo, um `kubectl edit` de emergência), ela não deveria ficar assim: uma aplicação com sincronização automática reverte esse tipo de mudança na próxima reconciliação, e mesmo sem selfHeal ligado a mudança vive só na memória de quem a aplicou, sem sobreviver a uma reconstrução do node.

A recipe `just freeze` existe para esse resgate: ela roda um `kubectl get` do objeto, remove os campos que só fazem sentido num objeto vivo, listados na tabela abaixo, e produz um YAML limpo, pronto para commitar no lugar certo do repositório ou do satélite.

| Campo removido |
| --- |
| `resourceVersion` |
| `generation` |
| `managedFields` |
| `uid` |
| `.status` |

Ela só lê: o `kubectl get` roda por SSH no node e a limpeza acontece num contêiner na máquina do operador, então nada é reaplicado no cluster enquanto você decide onde o arquivo mora.

```bash
just freeze <kind> <nome> -n <namespace> > caminho/do/manifesto.yaml
```

Depois de commitado, o Argo passa a rastrear esse objeto como qualquer outro: a mudança que antes só existia no cluster agora tem uma origem no git, e uma reconstrução do node a partir do zero a recria sem depender de ninguém lembrar que ela existia. O commit também devolve a mudança ao caminho normal de revisão, onde os gates de infraestrutura a enxergam.

Se o objeto commitado pertence a uma aplicação com selfHeal, a próxima reconciliação deixa de revertê-lo, porque agora o git e o cluster concordam.

## Continue por aqui

O [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) explica por que cada um desses itens é um ativo e o que os protege.
