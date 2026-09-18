# Modelo de ameaças

<!-- source-of-trust paths=".sops.yaml .tools/sops-recipients.sh .tools/sops-drill.sh .tools/sops-sync.sh .tools/sops-rotate.sh" -->

Este repositório descreve, e em parte controla, um cluster k3s de um nó só que hospeda serviços públicos de uma pessoa. O modelo abaixo diz o que se está protegendo, por onde um atacante entraria, o que já barra cada caminho e o que continua em aberto. Ele existe para que uma mudança de infraestrutura possa ser julgada contra uma lista explícita, e não contra a intuição de quem a escreveu.

## O que se protege

Os ativos, em ordem de gravidade se perdidos ou comprometidos:

- Os dados dos serviços. O Postgres do blog não tem backup hoje, então perda de volume é perda total.
- Qualquer chave privada age listada em `.sops.yaml`, hoje a do node, a de rotina do operador na Secure Enclave e a de desastre no Bitwarden. Quem tem uma delas decifra todo `SopsSecret` commitado em qualquer satélite.
- A credencial de administrador do cluster, isto é, o kubeconfig e a chave SSH de root do nó.
- O API token da Cloudflare em `tofu/cloudflare/cloudflare.sops.env`. Quem o tem redireciona o tráfego do blog trocando o ingress do túnel ou o DNS.
- A capacidade de publicar em `main` deste repositório e dos satélites, porque o Argo aplica o que está lá sem intervenção humana.
- A disponibilidade dos serviços públicos.

## Fronteiras de confiança

```mermaid
flowchart LR
  subgraph operador["Máquina do operador"]
    ansible["Ansible + all.yml"]
    kubeconfig["kubeconfig"]
  end
  subgraph github["GitHub"]
    infra["hl-infrastructure main"]
    sat["repositórios satélites main"]
    actions["Actions: ci, docs, renovate"]
    ghcr["GHCR: imagens sha-commit"]
  end
  subgraph node["Nó k3s"]
    ssh["sshd"]
    api["API do k3s"]
    argo["ArgoCD"]
    ss["sops-secrets-operator: chave privada age"]
    apps["workloads"]
  end
  internet["Internet"]
  ansible -->|SSH, chave do operador| ssh
  kubeconfig -->|6443 só de dentro do node, via SSH| api
  argo -->|pull| infra
  argo -->|pull, projeto satellites| sat
  kargo[Kargo] -->|Warehouse| ghcr
  kargo -->|argocd-update| argo
  internet -->|túnel Cloudflare| apps
```

Cada seta cruza uma fronteira, e cada fronteira tem um controle que a sustenta.

Da máquina do operador para o nó, a entrada é SSH com a chave que o operador autorizou no nó antes do primeiro bootstrap, senha desabilitada pela role `ssh_hardening` e `fail2ban` limitando tentativas. A API do k3s não aceita conexão de rede nenhuma: nem da rede local, nem da tailnet; o `kubectl` roda no próprio node, por SSH, e o `.local/operator/kubeconfig` que a role `k3s` traz só serve como cópia do arquivo. O que está fora desse controle: o kubeconfig e o `all.yml` ficam em texto claro no disco do operador, protegidos só pela cifragem de disco da máquina e pelo `.gitignore`; um comprometimento dessa máquina é comprometimento total do cluster, e a página [estado fora do git](../operacional/estado-fora-do-git.md) lista tudo o que vive só ali.

Do GitHub para o cluster, o Argo puxa `main` deste repositório com o projeto `infra`, que tem permissão ampla, e `main` de cada satélite de terceiro com o projeto `satellites`, que só cria recurso de namespace, mais `StorageClass`. O projeto `default` que o Argo cria na instalação está esvaziado, para que um `Application` filho não escape dessa restrição declarando outro projeto. Consequência direta: quem consegue escrever em `main` deste repositório administra o cluster, e quem consegue escrever em `main` de um satélite de terceiro administra só o namespace daquele satélite. A proteção real desses branches é a conta do GitHub com MFA e o ruleset que exige pull request; o dono do repositório pode contorná-lo, e cada push direto em `main` fica registrado como bypass no histórico do GitHub.

O único satélite deste cluster, o blog, é uma exceção deliberada a essa fronteira: suas `Application`s vivem neste mesmo repositório, sob o projeto `satellites` (o teto de permissão continua o mesmo), então quem administra este repositório já administra o namespace do blog de qualquer forma, sem precisar de um segundo repositório. Isso reduz o número de lugares a proteger, não a superfície administrável por quem já escreve aqui; veja "Por que o blog não é um satélite de verdade" em [GitOps: root e satélites](gitops-root-e-satelites.md).

Do GHCR para o cluster, o `Warehouse` do Kargo observa a tag `main` do pacote do satélite e, a cada digest novo, o `Stage` escreve esse digest na `Application` do Argo (veja [Rollout de imagens](rollout-de-imagens.md)). Quem consegue publicar nesse pacote do GHCR consegue rodar código no namespace do satélite; a barreira é a permissão de escrita no pacote, que só a pipeline do repositório do satélite tem via `GITHUB_TOKEN`. O Kargo só escreve na `Application` que carrega a anotação `kargo.akuity.io/authorized-stage` apontando para aquele `Stage`, e o que ele grava é o digest, não a tag, então mover a tag depois não muda o que roda até a próxima promoção, que fica registrada.

Das Actions para o GitHub, o `ci` e o `docs` rodam com `contents: read` e sem credencial persistida no checkout, então um passo comprometido lê o repositório público e nada mais. O `renovate` é o único com token de escrita, guardado num environment restrito a `main`, e só ele pode abrir PRs; o merge continua humano. Toda action é pinada por SHA e auditada por `zizmor` a cada push.

Da Internet para os serviços, nada chega direto ao nó: o blog é exposto por um túnel Cloudflare saindo de dentro do cluster, e o firewall do nó não abre porta de serviço. O que fica exposto é a porta 22, restrita como descrito acima; a 6443 não abre em zona nenhuma.

Manter os serviços fora de um `Service` exposto não é preferência de estilo. Uma regra de firewalld filtra a chain `INPUT`, que só vê tráfego destinado ao próprio host, e uma `Service` do tipo `LoadBalancer` ou `NodePort` chega por um DNAT que muda o destino do pacote antes dele ser avaliado. Esse tráfego passa então pela chain `FORWARD`, e a regra de firewalld sobre a porta nunca é sequer consultada. É por isso que a role `k3s` desliga o Traefik e o ServiceLB embutidos: expor algo assim tornaria qualquer regra de firewall sobre aquela porta uma proteção falsa. Já um processo que escuta direto na interface do host, como o k3s na 6443 ou o Traefik na 443, é realmente visto e filtrado pela chain `INPUT`, e é o que permite deixar a 6443 fechada e a 443 aberta só na zona da tailnet.

O [ingress](ingress.md) é construído sobre essa mesma regra: o Traefik roda com `hostNetwork` e escuta nas portas 80 e 443 do node, sem `Service` no caminho, e a zona `tailscale` do firewalld é a única que as libera, de modo que da rede local e da Internet elas continuam fechadas. O preço é um processo sem privilégio escutando em porta baixa no namespace de rede do host, o que exigiu baixar `net.ipv4.ip_unprivileged_port_start` para 80, uma concessão registrada na role `sysctl_hardening`.

Dentro do cluster, o sops-secrets-operator guarda a chave privada age no `Secret` `sops-age-key-file`, no namespace `sops`; os destinatários públicos correspondentes vivem em `.sops.yaml`, commitados neste repositório, porque cifrar com eles não permite decifrar nada. Qualquer workload que consiga ler `Secret` nesse namespace decifra tudo; o projeto `satellites` não pode criar `ClusterRole`, então um satélite não consegue se conceder essa leitura por GitOps. Um `Pod` privilegiado ou com montagem do host é barrado antes de chegar ao cluster pelos gates `kube-linter`, `checkov` e `trivy config` sobre os charts renderizados, mas esses gates só cobrem os charts Helm deste repositório; a política de rede e de recursos de um satélite de terceiro é responsabilidade do satélite. A do blog está fora dessa exceção: como suas `NetworkPolicy`, `ResourceQuota` e `LimitRange` também vivem neste repositório agora, elas ficam sujeitas às mesmas convenções de revisão daqui, ainda que não passem pelos mesmos gates de chart Helm, por não serem chart.

A tailnet acrescenta uma fronteira que não existia: um dispositivo autenticado no Tailscale alcança o SSH e o DNS interno do node de qualquer lugar, e nada além do node: ele não anuncia rota, então a rede local por trás dele continua fora da tailnet. O que define essa fronteira é a identidade Tailscale do operador e a ACL da tailnet, que este repositório não gerencia. O que o repositório controla é o que o node aceita de quem chega por ali: só `ssh` e `dns` na zona `tailscale` do firewalld, nenhuma policy de encaminhamento, e um DNS que recusa qualquer nome fora de `guesant.internal`. Uma conta Tailscale comprometida é, portanto, equivalente a estar na rede local do operador: chega ao SSH, que continua exigindo a chave, e à API do k3s, que continua restrita aos CIDRs declarados. O ganho é o inverso: com a tailnet funcionando, o SSH pode deixar de existir na interface da rede local, o que hoje ainda não foi feito para não trancar o operador antes de a tailnet estar provada.

## O caminho de um segredo

A sequência abaixo é o único caminho pelo qual um valor sensível chega a um pod. Em nenhum ponto o texto claro passa pelo git nem pelo Argo.

```mermaid
sequenceDiagram
    participant Op as Operador
    participant Git as Repositório do satélite
    participant Argo as ArgoCD
    participant SSO as sops-secrets-operator (cluster)
    participant Pod as Pod
    Op->>Git: .sops.yaml (destinatários públicos age, commitados)
    Op->>Op: just sops-sync arquivo.yaml (cifra sem nenhuma chave privada)
    Op->>Git: commit do SopsSecret
    Argo->>Git: pull
    Argo->>SSO: apply do SopsSecret
    SSO->>SSO: decifra com a chave privada age do node
    SSO->>Pod: cria o Secret no namespace
```

O `argocd_github_webhook_secret` segue outro caminho, mais curto: fica cifrado em `secrets.sops.yaml`, commitado, e o Ansible o decifra na máquina do operador e o entrega ao node por SSH; quem lê o repositório vê só o texto cifrado. A chave SSH do operador nem passa pelo Ansible: ela já precisa estar autorizada no node para o primeiro bootstrap entrar. A chave privada age do node nem isso: ela nasce dentro do próprio node, na primeira execução da role `sops_age_key`, e nunca existe em texto claro fora dele.

`.sops.yaml` lista destinatários numa lista age só, sob um único `key_group`: qualquer chave privada correspondente a qualquer entrada da lista decifra sozinha, sem depender das outras. Não há número fixo de destinatários nem papéis fixos. Os subcomandos `add <rótulo> <chave pública>`, `update`, `remove` e `list` de `just sops-recipients` operam sobre entradas identificadas só por um rótulo em comentário, como `# node` ou `# operator-se`, e o nome é livre. O `sync-node [rótulo]` é uma conveniência sobre esse mesmo mecanismo: ele sabe ler a chave pública do `Secret` do cluster e manter uma entrada sincronizada com ela, `node` por padrão, ou qualquer outro rótulo passado, o que serve se um segundo node algum dia entrar neste cluster ou em outro que compartilhe este `.sops.yaml`.

Cifrar um `SopsSecret` novo com `just sops-sync <arquivo>`, assim como o gate `security-sopssecrets`, precisa só das chaves públicas, sem chave privada nenhuma envolvida. Sem argumento, `just sops-sync` faz o mesmo para todo satélite de uma vez, arquivo por arquivo, e pede a identidade que decifra apenas no arquivo que de fato precisa ser resincronizado, nunca antecipadamente para o lote inteiro. Cifrar um satélite novo num lote onde os demais já estão cifrados e em dia não trava esperando chave nenhuma.

Isso rotaciona quem consegue decifrar, mas não troca a chave de conteúdo (a DEK) que cifra o valor em si; `just sops-rotate` faz exatamente isso, gera uma DEK nova pra cada `SopsSecret` e recifra os valores com ela, sem alterar quem tem acesso. Como todo `SopsSecret` já cifrado precisa ser decifrado antes de ganhar uma DEK nova, `sops-rotate` sempre exige `SOPS_AGE_KEY_FILE`, mesmo rodando sobre um arquivo só.

Um `.sops.yaml` alterado sem o `sops-sync` correspondente não é um erro silencioso: o gate `security-sopssecrets` compara, para cada `SopsSecret`, o conjunto de destinatários gravado no arquivo contra o conjunto atual de `.sops.yaml`, e falha em qualquer divergência, tanto uma chave que entrou e ainda não foi propagada quanto uma que saiu e ainda decifraria o segredo.

As credenciais do OpenTofu seguem o mesmo modelo, com escolhas que limitam o estrago de um vazamento. O API token da Cloudflare tem só as permissões de túnel e DNS, e nunca a de criar outros tokens, então quem o obtém consegue desviar o tráfego do blog mas não escalar para o resto da conta. E o token do túnel nunca passa pelo OpenTofu: ele vai da API da Cloudflare direto para um `SopsSecret`, então o `terraform.tfstate` commitado, mesmo que alguém quebre a cifragem dele, só revela IDs e os registros DNS. O state cifrado protege contra um vazamento do repositório; ele não protege contra quem já tem uma das chaves age, porque a passphrase, em `tofu/state.sops.env`, é cifrada para os mesmos destinatários que o API token.

O token de join do k3s segue o mesmo caminho, mas na direção contrária: `k3s_join_token`, cifrado em `ansible/group_vars/all/secrets.sops.yaml` para os mesmos destinatários de `.sops.yaml`, é a fonte do valor, e é a role `k3s` quem o grava no node, não o contrário. Isso amplia o que uma chave age vazada entrega: além de decifrar os `SopsSecret` e as credenciais do OpenTofu, ela revela um token que permite juntar um node ao cluster, o que só vira ataque para quem também alcança a porta 6443, fechada para toda rede. A troca foi aceita porque, sem um valor declarado, perder o node levaria junto o único registro do token; com o git como fonte, `just rotate-token` converge o node para o valor já commitado, e não existe cópia separada que possa ficar desatualizada.

Hoje o repositório usa esse mecanismo para manter, além da chave do node, uma chave de rotina do operador e uma chave de desastre. A de rotina é uma identidade `age-plugin-se` presa à Secure Enclave do Mac, no formato `age1se1...`, gerada com `just age-se-keygen` e nunca exportável dali. Ela é criada com `--access-control=any-biometry-or-passcode`, então cada decifragem exige biometria ou passcode do operador no momento do uso, e não só a posse física do Mac; é uma chave mestra fora de disco e com uso auditado.

A de desastre é um par age comum, cuja metade privada vive só numa nota segura do Bitwarden, gerada com `just age-keygen` e nunca escrita em disco por este repositório. Ela não decifra nada no dia a dia, é redundância pura: cobre o cenário em que o node e o Mac do operador se perdem juntos, e o `just sops-drill-dr` existe para provar periodicamente que ela ainda funciona. Nada impede adicionar mais uma chave, trocar a de rotina por outra, ou remover a de desastre; o único efeito de remover uma entrada é que a chave privada correspondente para de decifrar segredos cifrados depois disso.

## O que fica fora do modelo

Um atacante com acesso físico ao nó ou ao hipervisor. Uma vulnerabilidade zero-day no k3s, no Cilium ou no kernel antes do Renovate propor a versão corrigida e ela ser aplicada por um novo `bootstrap`. Um comprometimento da conta do GitHub do dono com MFA vencida. Esses cenários não têm mitigação declarada aqui e devem ser tratados como perda total do cluster, com reconstrução a partir do repositório; os dados do Postgres do blog não sobrevivem, porque não há backup hoje.

## Continue por aqui

O [SECURITY.md](https://github.com/guesant/hl-infrastructure/blob/main/SECURITY.md) diz como reportar uma falha que este modelo não previu. A página [GitOps: root e satélites](gitops-root-e-satelites.md) detalha as permissões de cada projeto do Argo, e [a pipeline de CI](ci.md) lista os gates que barram um manifesto perigoso antes do apply. O [checklist de segurança](checklist-de-seguranca.md) confronta este modelo com as recomendações de guias públicos e lista as lacunas conhecidas.
