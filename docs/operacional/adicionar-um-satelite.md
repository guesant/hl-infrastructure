# Adicionar um satélite novo

Um satélite é uma aplicação do ArgoCD que aponta para a pasta de GitOps de outro repositório, dentro do projeto de satélites. A aplicação raiz em [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root) sincroniza sozinha tudo que existir dentro de [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications); a aplicação de um satélite novo, porém, não é mais um arquivo próprio, é um item numa lista, gerado pelo chart `argocd/apps/satellites/launcher` a partir do arquivo de values. Nenhum passo manual no cluster é necessário para essa parte.

Este formato existe para um satélite que vive num repositório de terceiro. O blog também usa o mesmo chart, mas aponta para a pasta Helm deste repositório e permanece no values do launcher como exemplo completo.

Um satélite novo, de um repositório separado, se cria com a recipe abaixo. Ela roda num contêiner e só edita um arquivo de values no seu clone, sem falar com o cluster, então rodá-la não compromete nada antes de você decidir se vai commitar o resultado.

```bash
just satellite-add nome https://github.com/org/repo.git caminho/gitops/applications
```

A recipe acrescenta um item à lista de satélites do arquivo de values do launcher e recusa um nome já existente. Ela também recusa um nome que não case com o padrão `^[a-z][a-z0-9-]*$`, porque esse mesmo texto vira o nome da aplicação no namespace `argocd`, e um nome inválido só apareceria como erro do lado do Argo.

O template do launcher itera essa lista e emite, para cada item, a mesma aplicação que antes era escrita à mão por arquivo; [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md) explica o mecanismo geral, e [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md#satelites-e-entrega-do-kargo-um-chart-com-array-nao-um-arquivo-por-instancia) explica por que esse desenho venceu a alternativa nativa do ArgoCD, o ApplicationSet.

O item da lista tem os campos da tabela abaixo. O campo de onda de sincronização tem um padrão que coloca todo satélite depois de tudo o que o root instala, cujas ondas vão da que cria as classes de armazenamento e os namespaces até a mais tardia; mexer nele só faz sentido para ordenar um satélite em relação a outro.

| Campo | O que é |
| --- | --- |
| `name` | nome do satélite |
| `repoURL` | URL do repositório de terceiro |
| `path` | pasta, dentro do outro repositório, com só os objetos de controle do Argo daquele satélite |
| `destinationNamespace` | namespace da aplicação filha, `argocd` por padrão |
| `helmReleaseName` | nome da release Helm quando a fonte não é um diretório de manifests |
| `annotations` | anotações adicionais da `Application`, como a autorização do Stage do Kargo |
| `syncWave` | opcional, `10` por padrão |

O projeto e o bloco de política de sincronização que o template emite são os mesmos de toda aplicação deste repositório; [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) explica o que cada opção resolve e por que o projeto de satélites é restrito a recursos de namespace, com namespace, classe de armazenamento e o projeto do Kargo como exceções de escopo de cluster liberadas.

Depois de rodar a recipe, o resto é o caminho normal de qualquer mudança deste repositório. Renderize antes de commitar: a recipe de renderização materializa a aplicação nova a partir da lista, e é aí que um caminho errado ou uma URL com typo aparece, em vez de virar uma aplicação quebrada no cluster. O push é o que efetiva a mudança, porque é do git que o Argo lê.

```bash
just infra-render-charts
git add argocd/apps/satellites/launcher/values.yaml
git commit
git push
just status
```

O Argo detecta a mudança sozinho no próximo ciclo de sincronização periódica, porque a aplicação do launcher já sincroniza automaticamente. A recipe de status confirma que a aplicação nova apareceu e está sincronizada e saudável.

Quando ela aparece mas não sai do estado fora de sincronia, os dois motivos prováveis são o caminho apontando para uma pasta que não existe no outro repositório e uma aplicação filha pedindo um recurso de escopo de cluster que o projeto de satélites não autoriza.

## O que o outro repositório precisa declarar

As aplicações filhas, dentro da pasta de GitOps do outro repositório, devem repetir o mesmo bloco de política de sincronização que o template do launcher declara. Sem esse bloco, uma aplicação filha fica sem sincronização automática, sem autocorreção e sem poda, e o satélite passa a depender de alguém apertar sync na interface a cada mudança.

A onda neles é livre, porque o Argo só compara ondas entre irmãos da mesma aplicação pai.

### Atualização automática de imagem

O Kargo já roda no cluster, e a promoção de imagem de um satélite é declarada num projeto de entrega, com o mesmo tratamento em lista: o arquivo de values desse chart tem uma lista de satélites, e os cinco templates da tabela abaixo emitem, por item, o namespace correspondente já com o label de projeto do Kargo e as labels de [Pod Security](../aprender/jobs-cronjobs-e-securitycontext.md), mais os demais objetos que esses templates declaram.

| Template | Emite |
| --- | --- |
| `namespace.yaml` | o namespace `<nome>-delivery` |
| `project.yaml` | o `Project` do Kargo |
| `project-config.yaml` | o `ProjectConfig`, com a promoção automática |
| `warehouse.yaml` | o `Warehouse` que observa o registry |
| `stage.yaml` | o `Stage` de produção |

O namespace gerado já nasce com Pod Security restrito nos três modos, enforce, warn e audit, como todo namespace criado daqui. A configuração de projeto que vem junto liga a promoção automática do estágio de produção, de modo que, depois desta configuração, nenhuma imagem nova exige ação manual.

O nome do satélite não pode coincidir com o namespace da própria aplicação, porque um projeto do Kargo é também um namespace. O sufixo `-delivery` que o chart acrescenta torna a colisão improvável, mas não impossível: um satélite batizado de `blog-delivery` disputaria o namespace do projeto de entrega do blog. Escolha o nome antes de rodar a recipe, porque trocá-lo depois faz o Argo podar o projeto antigo e criar outro do zero, levando junto o histórico de Freight.

```bash
just satellite-delivery-add nome ghcr.io/org/imagem application-filha caminho.do.values
```

A recipe preenche o item inteiro a partir dos quatro argumentos, completando os campos do `Warehouse` com valores padrão. Vale abrir o item gerado antes de commitar, porque é ele, e não a linha de comando, que o chart consome. São estes os campos:

| Campo | O que é |
| --- | --- |
| `name` | o nome do satélite, que dá nome ao namespace `<nome>-delivery` |
| `childApp` | o nome da `Application` que a promoção atualiza |
| `images[].imageRepo` | o repositório da imagem publicada |
| `images[].valuesPath` | o caminho do values Helm que recebe a tag, por exemplo `application.deployment.image.tag` |
| `images[].imageTagValue` | a expressão `main@${{ imageFrom("...").Digest }}` já montada com o repositório certo |
| `images[].imageSelectionStrategy`, `images[].constraint`, `images[].strictSemvers`, `images[].discoveryLimit` | os campos do `Warehouse`, todos com um valor padrão sensato |

O Warehouse acompanha a tag do branch principal pela estratégia de digest: cada vez que a pipeline do outro repositório publica e o digest atrás da tag muda, nasce um Freight novo, e a política de promoção automática o leva ao estágio de produção.

O passo de atualização do ArgoCD grava o digest como parâmetro Helm da própria aplicação, sem commit em nenhum repositório; o git continua declarando a tag base como ponto de partida, e o digest corrente fica visível na consulta à aplicação pelo `kubectl` e na UI do Kargo. A consulta ao registry acontece a cada dois minutos, então a defasagem entre publicar a imagem e ver o rollout é dessa ordem de grandeza, não instantânea.

Um satélite que renderiza a imagem a partir de um chart precisa de atenção no campo do valor de tag, porque ele tem de produzir o formato que o chart espera; renderize e confira antes de ligar. Se a imagem for publicada só com tags imutáveis, sem tag móvel, ajuste os três campos da tabela abaixo.

Nos dois casos o teste barato é renderizar e ler o estágio gerado, onde o valor aparece exatamente como o Kargo vai gravá-lo como parâmetro Helm.

| Campo | Valor para tags imutáveis |
| --- | --- |
| `imageSelectionStrategy` | `NewestBuild` |
| `allowTagsRegexes` | `["^sha-[0-9a-f]{40}$"]` |
| `imageTagValue` | usa `imageFrom(...).Tag` em vez do digest |

A recipe recusa um nome já existente e termina imprimindo a edição que continua manual, porque toca um arquivo no repositório do satélite. A saída da recipe já traz essa edição preenchida com o nome da `Application` filha, pronta para copiar:

1. A `Application` filha (a que a recipe chamou de `childApp`) precisa carregar a anotação `kargo.akuity.io/authorized-stage: <nome>-delivery:prod`, a prova de que quem pode editar aquela `Application` consentiu com aquele `Stage` a editar; sem ela a promoção falha com erro explícito.

O `satellites-launcher` já ignora genericamente `spec.source.helm.parameters` das aplicações filhas que ele gera. Esse campo é o ponto de escrita do Kargo e não deve ser duplicado em cada novo satélite.

Depois dessas edições, o fluxo de commit é o mesmo do satélite: renderizar para conferir, commitar, dar push e checar o status. Na conferência, olhe se o estágio renderizado aponta para a aplicação filha certa, porque um valor errado nesse campo não quebra nada na sincronização e só aparece quando a primeira promoção falha. A partir do sync, o Warehouse já começa a observar o registry sozinho, sem nenhum passo adicional.

### Um banco Postgres

O operador CloudNativePG já está instalado. Ele roda no namespace `cnpg-system` e atende o cluster inteiro, então nenhum satélite precisa instalar operador nenhum para ter banco. Um satélite que precisa de banco declara o próprio `Cluster` no próprio namespace; o formato de referência é este:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  namespace: nome-do-namespace
  annotations:
    argocd.argoproj.io/sync-options: Prune=false,Delete=false
spec:
  instances: 1
  storage:
    size: 5Gi
  bootstrap:
    initdb:
      database: app
      owner: app
```

O Cluster não declara [classe de armazenamento](../aprender/modelo-de-armazenamento-do-kubernetes.md) porque a classe padrão do cluster é a única que existe, `local-path` com política de retenção, e não há outra a escolher. O chart de armazenamento que a declara também usa `volumeBindingMode: WaitForFirstConsumer`, então o diretório no node só nasce quando o primeiro pod que monta o volume é agendado.

A retenção tem uma consequência prática que vale conhecer antes de precisar dela: apagar a [reivindicação de volume](../aprender/modelo-de-armazenamento-do-kubernetes.md) não apaga o dado, e o caminho de volta está em [restaurar um volume retido](restaurar-um-volume-retido.md).

As opções de sync protegem os dados de um erro de GitOps em momentos distintos, listadas na tabela abaixo. Isso importa porque toda aplicação daqui carrega um [finalizer](../arquitetura/gitops-root-e-satelites.md) que faz um `git rm` do arquivo dela levar junto tudo o que ela criou; sem a segunda opção, remover o satélite do git apagaria o banco. Com ambas, o volume só vai embora por uma remoção manual e deliberada.

| Opção | Protege contra |
| --- | --- |
| `Prune=false` | Argo apagar o Cluster quando o arquivo some do repositório |
| `Delete=false` | perda do banco quando a própria aplicação é apagada, via o finalizer `resources-finalizer.argocd.argoproj.io` |

Este objeto não entra no array das seções anteriores, porque um banco é dado com estado dedicado, não estrutura repetível sem variação; cada satélite que precisar de um declara o Cluster acima diretamente.

Um item de array só funciona quando todas as instâncias têm a mesma forma e diferem em valores, e dois bancos costumam diferir em tamanho, em bootstrap e em quem os consome. Copiar o bloco acima e ajustá-lo é mais honesto do que espremer essas diferenças em campos de values que ninguém vai reutilizar.

Este Cluster não tem backup contínuo em object storage: o operador de backup que fornecia isso foi removido do cluster de propósito. Sem ele, a perda do volume é perda total dos dados do satélite; veja [estado fora do git](estado-fora-do-git.md). Reinstalar o plugin é um pré-requisito antes de qualquer satélite novo poder declarar `spec.plugins` com `barman-cloud.cloudnative-pg.io`.

A senha do role criado pelo bootstrap do banco fica de fora do git de propósito: o CNPG gera ela sozinho e mantém num segredo próprio, por padrão nomeado a partir do cluster, sem passar por nenhum segredo cifrado do SOPS. Isso significa que ninguém, nem quem tem acesso a este repositório nem quem tem uma das chaves age, consegue ler essa senha fora do próprio cluster; só quem já tem acesso ao namespace do satélite consegue.

Uma consequência menor é que nenhum drill de decifragem cobre essa senha, porque não existe arquivo cifrado que a contenha para a recipe de simulação testar.

O custo é não existir rotação automatizada dela hoje. Trocar a senha significa deixar o CNPG gerar uma nova, apagando o segredo que ele mantém, e reiniciar o que a consome, um processo manual por enquanto.

Se um satélite precisar de mais de um role ou de controle explícito sobre quando a senha muda, `spec.managed.roles` é o mecanismo do CNPG para isso, mas evite `passwordSecret` apontando para um segredo cifrado do SOPS: a decisão deste cluster é manter toda senha de role do Postgres fora do git.

## Continue por aqui

Para entender a razão de existir dessa separação entre a aplicação raiz e os satélites, o mecanismo de array por trás das recipes deste guia, e o que cada opção de política de sincronização resolve, veja [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) na arquitetura. Para entender o caminho inteiro de uma imagem publicada até o pod, e o que fazer quando nada promove, veja [rollout de imagens](../arquitetura/rollout-de-imagens.md).
