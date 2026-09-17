# Adicionar um satélite novo

Um satélite é uma `Application` do ArgoCD que aponta para a pasta de GitOps de outro repositório, dentro do projeto `satellites`. A aplicação raiz em [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root) sincroniza sozinha tudo que existir dentro de [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications); a `Application` de um satélite novo, porém, não é mais um arquivo próprio, é um item numa lista, gerado pelo chart `argocd/apps/satellites/launcher` a partir de `values.yaml`. Nenhum passo manual no cluster é necessário para essa parte.

Este formato existe para um satélite que vive num repositório de terceiro; o único satélite deste cluster, o blog, vive direto neste repositório (veja "Por que o blog não é um satélite de verdade" em [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md)) e não segue esse formato. Um satélite novo, de um repositório separado, se cria com:

```bash
just satellite-add nome https://github.com/org/repo.git caminho/gitops/applications
```

A recipe acrescenta um item à lista `satellites` de `argocd/apps/satellites/launcher/values.yaml` e recusa um nome já existente. `argocd/apps/satellites/launcher/templates/application.yaml` itera essa lista com `{{- range .Values.satellites }}` e emite, para cada item, a mesma `Application` que antes era escrita à mão por arquivo; [gerar várias instâncias de um recurso com Helm](../aprender/helm-templating-de-lista.md) explica o mecanismo geral, e [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md#satelites-e-entrega-do-kargo-um-chart-com-array-nao-um-arquivo-por-instancia) explica por que esse desenho venceu a alternativa nativa do ArgoCD, o `ApplicationSet`.

O item da lista tem quatro campos: `name`, `repoURL`, `path` (a pasta, dentro do outro repositório, que contém só os objetos de controle do Argo daquele satélite, não os manifestos da aplicação em si) e `syncWave` (opcional, `10` por padrão). O `project: satellites` e o bloco de `syncPolicy` que o template emite são os mesmos de todo `Application` deste repositório; [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) explica o que cada opção de `syncPolicy` resolve e por que o projeto `satellites` é restrito a recursos de namespace, com `Namespace`, `StorageClass` e o `Project` do Kargo como as três exceções de escopo de cluster liberadas.

Depois de rodar a recipe:

```bash
just render-charts
git add argocd/apps/satellites/launcher/values.yaml
git commit
git push
just status
```

O Argo detecta a mudança sozinho no próximo ciclo de sincronização (por padrão, a cada três minutos), porque a `Application` `satellites-launcher` já sincroniza automaticamente. `just status` confirma que a `Application` nova apareceu e está `Synced`/`Healthy`.

## O que o outro repositório precisa declarar

Os `Application` filhos, dentro da pasta de GitOps do outro repositório, devem repetir o mesmo bloco de `syncPolicy` que `argocd/apps/satellites/launcher/templates/application.yaml` declara. A onda neles é livre, porque o Argo só compara ondas entre irmãos da mesma `Application` pai.

### Atualização automática de imagem

O Kargo já roda no cluster, e a promoção de imagem de um satélite é declarada num projeto de entrega, com o mesmo tratamento em lista: `argocd/apps/satellites/delivery/values.yaml` tem uma lista `satellites`, e os templates desse chart (`namespace.yaml`, `project.yaml`, `project-config.yaml`, `warehouse.yaml`, `stage.yaml`) emitem, por item, o namespace `<nome>-delivery` já com o label `kargo.akuity.io/project: "true"` e as labels de Pod Security, mais os quatro objetos do Kargo. O nome do satélite não pode coincidir com o namespace da própria aplicação, porque um `Project` do Kargo é também um namespace.

```bash
just satellite-delivery-add nome ghcr.io/org/imagem application-filha caminho.do.values
```

O item que a recipe acrescenta tem estes campos: `name`, `imageRepo` (o repositório da imagem publicada), `childApp` (o nome da `Application` que a promoção atualiza), `valuesPath` (o caminho do values Helm que recebe a tag, por exemplo `application.deployment.image.tag`), `imageTagValue` (a expressão `main@${{ imageFrom("...").Digest }}` já montada com o repositório certo) e os campos do `Warehouse` (`imageSelectionStrategy`, `constraint`, `strictSemvers`, `discoveryLimit`, todos com um valor padrão sensato). O `Warehouse` acompanha a tag `main` pela estratégia `Digest`: cada vez que a pipeline do outro repositório publica e o digest atrás da tag muda, nasce um `Freight` novo, e a política de promoção automática o leva ao `Stage` `prod`. O passo `argocd-update` grava `main@sha256:...` como parâmetro Helm da própria `Application`, sem commit em nenhum repositório; o git continua declarando a tag base como ponto de partida, e o digest corrente fica visível em `kubectl -n argocd get application nome -o yaml` e na UI do Kargo. Se o satélite renderiza a imagem a partir de um chart, o valor precisa produzir o formato que o campo do chart espera; renderize e confira antes de ligar. Quando a imagem for publicada só com tags imutáveis `sha-<commit>` e sem tag móvel, edite `imageSelectionStrategy` para `NewestBuild`, acrescente `allowTagsRegexes: ["^sha-[0-9a-f]{40}$"]` e troque `imageTagValue` para usar `imageFrom(...).Tag`.

A recipe recusa um nome já existente e termina imprimindo duas edições que continuam manuais, porque tocam arquivos fora da lista:

1. A `Application` filha (a que a recipe chamou de `childApp`) precisa carregar a anotação `kargo.akuity.io/authorized-stage: <nome>-delivery:prod`, a prova de que quem pode editar aquela `Application` consentiu com aquele `Stage` a editar; sem ela a promoção falha com erro explícito.
2. A `Application` `root` deste repositório precisa de um `ignoreDifferences` para `/spec/source/helm/parameters` dessa `Application`, como já existe para o blog em `argocd/root/application.yaml`, senão o `selfHeal` do root devolve a tag do git a cada reconciliação.

Depois das duas edições, o fluxo de commit é o mesmo do satélite: `just render-charts` para conferir, `git add`/`commit`/`push`, `just status`.

### Um banco Postgres

O operador CloudNativePG já está instalado. Um satélite que precisa de banco declara o próprio `Cluster` no próprio namespace; o formato de referência é este:

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

O `Cluster` não declara `storageClass`: a classe padrão do cluster é a única que existe, `local-path` com `Retain`, e a política de admissão não é necessária porque não há outra classe a escolher. `Prune=false,Delete=false` no `Cluster` protege os dados de um erro de GitOps em dois momentos distintos: `Prune=false` faz o Argo se recusar a apagá-lo quando o arquivo some do repositório, e `Delete=false` o preserva quando a própria `Application` é apagada, porque toda `Application` daqui carrega o finalizer `resources-finalizer.argocd.argoproj.io`, que faz um `git rm` do arquivo dela levar junto tudo o que ela criou. Sem a segunda opção, remover o satélite do git apagaria o banco. O volume só vai embora por uma remoção manual e deliberada. Este objeto não faz parte do array das duas seções anteriores, porque um banco é dado com estado dedicado, não estrutura repetível sem variação; cada satélite que precisar de um declara o `Cluster` acima diretamente.

Este `Cluster` não tem backup contínuo em object storage: o operador `cnpg-barman-plugin` que fornecia isso foi removido do cluster de propósito. Sem ele, a perda do volume é perda total dos dados do satélite; veja [estado fora do git](estado-fora-do-git.md). Reinstalar o plugin é um pré-requisito antes de qualquer satélite novo poder declarar `spec.plugins` com `barman-cloud.cloudnative-pg.io`.

A senha do role criado por `bootstrap.initdb.owner` fica de fora do git de propósito: o CNPG gera ela sozinho e mantém num `Secret` próprio (`<nome-do-cluster>-app`, por padrão), sem passar por nenhum `SopsSecret`. Isso significa que ninguém, nem quem tem acesso a este repositório nem quem tem uma das chaves age de `.sops.yaml`, consegue ler essa senha fora do próprio cluster; só quem já tem acesso ao namespace do satélite (`kubectl get secret`) consegue. O custo é não existir rotação automatizada dela hoje: trocar a senha significa deixar o CNPG gerar uma nova (apagando o `Secret` que ele mantém) e reiniciar o que a consome, um processo manual por enquanto. Se um satélite precisar de mais de um role ou de controle explícito sobre quando a senha muda, `spec.managed.roles` é o mecanismo do CNPG pra isso, mas evite `passwordSecret` apontando pra um `SopsSecret`: a decisão deste cluster é manter toda senha de role do Postgres fora do git.

## Continue por aqui

Para entender a razão de existir dessa separação entre a aplicação raiz e os satélites, o mecanismo de array por trás de `satellite-add`/`satellite-delivery-add`, e o que cada opção de `syncPolicy` resolve, veja [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) na arquitetura. Para entender o caminho inteiro de uma imagem publicada até o pod, e o que fazer quando nada promove, veja [rollout de imagens](../arquitetura/rollout-de-imagens.md).
