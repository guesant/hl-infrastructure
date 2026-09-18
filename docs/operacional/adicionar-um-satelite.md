# Adicionar um satélite novo

Um satélite é uma `Application` do ArgoCD que aponta para a pasta de GitOps de outro repositório, dentro do projeto `satellites`. A aplicação raiz em [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root) sincroniza sozinha tudo que existir dentro de [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications); a `Application` de um satélite novo, porém, não é mais um arquivo próprio, é um item numa lista, gerado pelo chart `argocd/apps/satellites/launcher` a partir de `values.yaml`. Nenhum passo manual no cluster é necessário para essa parte.

Este formato existe para um satélite que vive num repositório de terceiro; o único satélite deste cluster, o blog, vive direto neste repositório (veja "Por que o blog não é um satélite de verdade" em [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md)) e não segue esse formato. Um satélite novo, de um repositório separado, se cria com a recipe abaixo. Ela roda num contêiner e só edita um arquivo de values no seu clone, sem falar com o cluster, então rodá-la não compromete nada antes de você decidir se vai commitar o resultado.

```bash
just satellite-add nome https://github.com/org/repo.git caminho/gitops/applications
```

A recipe acrescenta um item à lista `satellites` de `argocd/apps/satellites/launcher/values.yaml` e recusa um nome já existente. Ela também recusa um nome que não case com `^[a-z][a-z0-9-]*$`, porque esse mesmo texto vira o nome da `Application` no namespace `argocd`, e um nome inválido só apareceria como erro do lado do Argo. `argocd/apps/satellites/launcher/templates/application.yaml` itera essa lista com `{{- range .Values.satellites }}` e emite, para cada item, a mesma `Application` que antes era escrita à mão por arquivo; [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md) explica o mecanismo geral, e [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md#satelites-e-entrega-do-kargo-um-chart-com-array-nao-um-arquivo-por-instancia) explica por que esse desenho venceu a alternativa nativa do ArgoCD, o `ApplicationSet`.

O item da lista tem os campos `name`, `repoURL`, `path` (a pasta, dentro do outro repositório, que contém só os objetos de controle do Argo daquele satélite, não os manifestos da aplicação em si) e `syncWave` (opcional, `10` por padrão). Esse padrão coloca todo satélite depois de tudo o que o root instala, cujas ondas vão de `-1`, a das classes de armazenamento e dos namespaces, até `3`; mexer nele só faz sentido para ordenar um satélite em relação a outro. O `project: satellites` e o bloco de `syncPolicy` que o template emite são os mesmos de todo `Application` deste repositório; [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) explica o que cada opção de `syncPolicy` resolve e por que o projeto `satellites` é restrito a recursos de namespace, com `Namespace`, `StorageClass` e o `Project` do Kargo como exceções de escopo de cluster liberadas.

Depois de rodar a recipe, o resto é o caminho normal de qualquer mudança deste repositório. Renderize antes de commitar: `just infra-render-charts` materializa a `Application` nova a partir da lista, e é aí que um `path` errado ou um `repoURL` com typo aparece, em vez de virar uma `Application` quebrada no cluster. O push é o que efetiva a mudança, porque é do git que o Argo lê.

```bash
just infra-render-charts
git add argocd/apps/satellites/launcher/values.yaml
git commit
git push
just status
```

O Argo detecta a mudança sozinho no próximo ciclo de sincronização periódica, porque a `Application` `satellites-launcher` já sincroniza automaticamente. `just status` confirma que a `Application` nova apareceu e está `Synced`/`Healthy`. Quando ela aparece mas não sai de `OutOfSync`, os dois motivos prováveis são o `path` apontando para uma pasta que não existe no outro repositório e uma `Application` filha pedindo um recurso de escopo de cluster que o projeto `satellites` não autoriza.

## O que o outro repositório precisa declarar

Os `Application` filhos, dentro da pasta de GitOps do outro repositório, devem repetir o mesmo bloco de `syncPolicy` que `argocd/apps/satellites/launcher/templates/application.yaml` declara. Sem esse bloco, uma `Application` filha fica sem `automated`, sem `selfHeal` e sem `prune`, e o satélite passa a depender de alguém apertar sync na interface a cada mudança, o que é exatamente o que este repositório não quer. A onda neles é livre, porque o Argo só compara ondas entre irmãos da mesma `Application` pai.

### Atualização automática de imagem

O Kargo já roda no cluster, e a promoção de imagem de um satélite é declarada num projeto de entrega, com o mesmo tratamento em lista: `argocd/apps/satellites/delivery/values.yaml` tem uma lista `satellites`, e os templates desse chart (`namespace.yaml`, `project.yaml`, `project-config.yaml`, `warehouse.yaml`, `stage.yaml`) emitem, por item, o namespace `<nome>-delivery` já com o label `kargo.akuity.io/project: "true"` e as labels de Pod Security, mais os demais objetos do Kargo que esses templates declaram. O namespace gerado já nasce com Pod Security em `restricted` nos três modos, enforce, warn e audit, como todo namespace criado daqui. O `ProjectConfig` que vem junto liga a promoção automática do `Stage` `prod`, de modo que, depois desta configuração, nenhuma imagem nova exige ação manual.

O nome do satélite não pode coincidir com o namespace da própria aplicação, porque um `Project` do Kargo é também um namespace. O sufixo `-delivery` que o chart acrescenta torna a colisão improvável, mas não impossível: um satélite batizado de `blog-delivery` disputaria o namespace do projeto de entrega do blog. Escolha o nome antes de rodar a recipe, porque trocá-lo depois faz o Argo podar o `Project` antigo e criar outro do zero, levando junto o histórico de `Freight`.

```bash
just satellite-delivery-add nome ghcr.io/org/imagem application-filha caminho.do.values
```

A recipe preenche o item inteiro a partir dos quatro argumentos, completando os campos do `Warehouse` com valores padrão. Vale abrir o item gerado antes de commitar, porque é ele, e não a linha de comando, que o chart consome. São estes os campos:

| Campo | O que é |
| --- | --- |
| `name` | o nome do satélite, que dá nome ao namespace `<nome>-delivery` |
| `imageRepo` | o repositório da imagem publicada |
| `childApp` | o nome da `Application` que a promoção atualiza |
| `valuesPath` | o caminho do values Helm que recebe a tag, por exemplo `application.deployment.image.tag` |
| `imageTagValue` | a expressão `main@${{ imageFrom("...").Digest }}` já montada com o repositório certo |
| `imageSelectionStrategy`, `constraint`, `strictSemvers`, `discoveryLimit` | os campos do `Warehouse`, todos com um valor padrão sensato |

O `Warehouse` acompanha a tag `main` pela estratégia `Digest`: cada vez que a pipeline do outro repositório publica e o digest atrás da tag muda, nasce um `Freight` novo, e a política de promoção automática o leva ao `Stage` `prod`. O passo `argocd-update` grava `main@sha256:...` como parâmetro Helm da própria `Application`, sem commit em nenhum repositório; o git continua declarando a tag base como ponto de partida, e o digest corrente fica visível em `kubectl -n argocd get application nome -o yaml` e na UI do Kargo. A consulta ao registry acontece a cada dois minutos, declarados no `interval` do `Warehouse`, então a defasagem entre publicar a imagem e ver o rollout é dessa ordem de grandeza, não instantânea.

Um satélite que renderiza a imagem a partir de um chart precisa de atenção no `imageTagValue`, porque o valor tem de produzir o formato que o campo do chart espera; renderize e confira antes de ligar. E se a imagem for publicada só com tags imutáveis `sha-<commit>`, sem tag móvel, edite `imageSelectionStrategy` para `NewestBuild`, acrescente `allowTagsRegexes: ["^sha-[0-9a-f]{40}$"]` e troque `imageTagValue` para usar `imageFrom(...).Tag`. Nos dois casos o teste barato é `just infra-render-charts` e ler o `Stage` gerado, onde o valor aparece exatamente como o Kargo vai gravá-lo como parâmetro Helm.

A recipe recusa um nome já existente e termina imprimindo as edições que continuam manuais, porque tocam arquivos fora da lista. Elas ficaram de fora do chart por morarem em arquivos de outro dono, um no repositório do satélite e outro no root deste. A saída da recipe já traz as duas preenchidas com o nome da `Application` filha, prontas para copiar; são estas:

1. A `Application` filha (a que a recipe chamou de `childApp`) precisa carregar a anotação `kargo.akuity.io/authorized-stage: <nome>-delivery:prod`, a prova de que quem pode editar aquela `Application` consentiu com aquele `Stage` a editar; sem ela a promoção falha com erro explícito.
2. A `Application` `root` deste repositório precisa de um `ignoreDifferences` para `/spec/source/helm/parameters` dessa `Application`, como já existe para o blog em `argocd/root/application.yaml`, senão o `selfHeal` do root devolve a tag do git a cada reconciliação.

Depois dessas edições, o fluxo de commit é o mesmo do satélite: `just infra-render-charts` para conferir, `git add`/`commit`/`push`, `just status`. Na conferência, olhe se o `Stage` renderizado aponta para a `Application` filha certa, porque um `childApp` errado não quebra nada na sincronização e só aparece quando a primeira promoção falha. A partir do sync, o `Warehouse` já começa a observar o registry sozinho, sem nenhum passo adicional.

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

O `Cluster` não declara `storageClass` porque a classe padrão do cluster é a única que existe, `local-path` com `Retain`, e não há outra a escolher. O chart `argocd/apps/platform/storage` que a declara também usa `volumeBindingMode: WaitForFirstConsumer`, então o diretório no node só nasce quando o primeiro pod que monta o volume é agendado. O `Retain` tem uma consequência prática que vale conhecer antes de precisar dela: apagar o `PersistentVolumeClaim` não apaga o dado, e o caminho de volta está em [restaurar um volume retido](restaurar-um-volume-retido.md).

As opções de sync protegem os dados de um erro de GitOps em momentos distintos. `Prune=false` faz o Argo se recusar a apagar o `Cluster` quando o arquivo some do repositório. `Delete=false` o preserva quando a própria `Application` é apagada, o que importa porque toda `Application` daqui carrega o finalizer `resources-finalizer.argocd.argoproj.io`, que faz um `git rm` do arquivo dela levar junto tudo o que ela criou; sem essa segunda opção, remover o satélite do git apagaria o banco. Com ambas, o volume só vai embora por uma remoção manual e deliberada.

Este objeto não entra no array das seções anteriores, porque um banco é dado com estado dedicado, não estrutura repetível sem variação; cada satélite que precisar de um declara o `Cluster` acima diretamente. Um item de array só funciona quando todas as instâncias têm a mesma forma e diferem em valores, e dois bancos costumam diferir em tamanho, em bootstrap e em quem os consome. Copiar o bloco acima e ajustá-lo é mais honesto do que espremer essas diferenças em campos de values que ninguém vai reutilizar.

Este `Cluster` não tem backup contínuo em object storage: o operador `cnpg-barman-plugin` que fornecia isso foi removido do cluster de propósito. Sem ele, a perda do volume é perda total dos dados do satélite; veja [estado fora do git](estado-fora-do-git.md). Reinstalar o plugin é um pré-requisito antes de qualquer satélite novo poder declarar `spec.plugins` com `barman-cloud.cloudnative-pg.io`.

A senha do role criado por `bootstrap.initdb.owner` fica de fora do git de propósito: o CNPG gera ela sozinho e mantém num `Secret` próprio (`<nome-do-cluster>-app`, por padrão), sem passar por nenhum `SopsSecret`. Isso significa que ninguém, nem quem tem acesso a este repositório nem quem tem uma das chaves age de `.sops.yaml`, consegue ler essa senha fora do próprio cluster; só quem já tem acesso ao namespace do satélite (`kubectl get secret`) consegue. Uma consequência menor é que nenhum drill de decifragem cobre essa senha, porque não existe arquivo cifrado que a contenha para `just sops-drill` testar.

O custo é não existir rotação automatizada dela hoje. Trocar a senha significa deixar o CNPG gerar uma nova, apagando o `Secret` que ele mantém, e reiniciar o que a consome, um processo manual por enquanto. Se um satélite precisar de mais de um role ou de controle explícito sobre quando a senha muda, `spec.managed.roles` é o mecanismo do CNPG para isso, mas evite `passwordSecret` apontando para um `SopsSecret`: a decisão deste cluster é manter toda senha de role do Postgres fora do git.

## Continue por aqui

Para entender a razão de existir dessa separação entre a aplicação raiz e os satélites, o mecanismo de array por trás de `satellite-add`/`satellite-delivery-add`, e o que cada opção de `syncPolicy` resolve, veja [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) na arquitetura. Para entender o caminho inteiro de uma imagem publicada até o pod, e o que fazer quando nada promove, veja [rollout de imagens](../arquitetura/rollout-de-imagens.md).
