# Adicionar um satélite novo

Um satélite é uma `Application` do ArgoCD que aponta para a pasta de GitOps de outro repositório, dentro do projeto `satellites`. A aplicação raiz em [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root) sincroniza sozinha tudo que existir dentro de [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications), então registrar um satélite novo é só adicionar um arquivo em `argocd/applications/satellites/`; nenhum passo manual no cluster é necessário.

Este formato existe para um satélite que vive num repositório de terceiro; o único satélite deste cluster, o blog, vive direto neste repositório (veja "Por que o blog não é um satélite de verdade" em [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md)) e não segue esse formato. Um satélite novo, de um repositório separado, se cria com `just satellite-add nome https://github.com/org/repo.git caminho/gitops/applications`, que escreve o arquivo abaixo em `argocd/applications/satellites/` e imprime os passos seguintes (commitar, dar push, conferir com `just status`); o modelo existe aqui só para quem quiser entender o que a recipe escreve ou editar um satélite depois de criado:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nome-do-satelite
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: satellites
  source:
    repoURL: https://github.com/guesant/outro-repositorio.git
    targetRevision: main
    path: caminho/para/gitops/applications
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  revisionHistoryLimit: 3
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
      allowEmpty: false
    syncOptions:
      - ServerSideApply=true
      - FailOnSharedResource=true
      - PruneLast=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

O `project: satellites` é obrigatório: esse projeto do Argo está restrito a recursos de namespace, com três exceções liberadas: `Namespace` (para o Argo criar e rotular o namespace de cada satélite), `StorageClass` e o `Project` do Kargo, que é de escopo de cluster porque um projeto dele é também um namespace. Um satélite não pode criar `ClusterRole`, `CustomResourceDefinition` ou qualquer outro recurso de escopo de cluster; se o outro repositório precisar disso, esse recurso pertence a este repositório, não a um satélite.

O `finalizers` com `resources-finalizer.argocd.argoproj.io` também é obrigatório: é ele que faz a remoção do arquivo do git remover do cluster o que a `Application` criou, em vez de deixar recursos órfãos; o que precisa sobreviver a isso (banco, volume) leva `Delete=false`, descrito adiante. A onda `10` e o bloco `syncPolicy` são os mesmos de todo `Application` daqui, e [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) explica o que cada opção resolve. Copie o bloco inteiro; um satélite sem `retry`, por exemplo, fica travado em erro na primeira vez que uma CRD demorar a subir.

O caminho em `source.path` deve apontar para uma pasta que contenha só os objetos de controle do Argo (`Application` e afins) daquele outro repositório, não os manifestos da aplicação em si; quem interpreta esses objetos de controle e sincroniza os manifestos de verdade é o Argo, recursivamente, a partir dali.

Depois de commitar o arquivo novo e dar push em `main` deste repositório, o Argo detecta a mudança sozinho no próximo ciclo de sincronização (por padrão, a cada três minutos) e cria a aplicação. Confirme com `just status`.

## O que o outro repositório precisa declarar

Os `Application` filhos, dentro da pasta de GitOps do outro repositório, devem repetir o mesmo bloco de `syncPolicy` acima. A onda neles é livre, porque o Argo só compara ondas entre irmãos da mesma `Application` pai.

### Atualização automática de imagem

O Kargo já roda no cluster, e a promoção de imagem de um satélite é declarada num projeto de entrega próprio, separado do namespace da aplicação: uma pasta como `argocd/apps/satellites/<nome>/delivery`, sincronizada por uma `Application` do projeto `satellites` que cria o namespace `<nome>-delivery` já com o label `kargo.akuity.io/project: "true"`, para o Kargo adotá-lo em vez de tentar criar um segundo. O nome não pode ser o mesmo do namespace da aplicação, porque um `Project` do Kargo é também um namespace. Dentro dessa pasta ficam quatro objetos, no modelo do blog em [argocd/apps/satellites/blog/delivery](https://github.com/guesant/hl-infrastructure/tree/main/argocd/apps/satellites/blog/delivery):

```yaml
apiVersion: kargo.akuity.io/v1alpha1
kind: Project
metadata:
  name: nome-do-satelite-delivery
---
apiVersion: kargo.akuity.io/v1alpha1
kind: ProjectConfig
metadata:
  name: nome-do-satelite-delivery
  namespace: nome-do-satelite-delivery
spec:
  promotionPolicies:
    - stage: prod
      autoPromotionEnabled: true
---
apiVersion: kargo.akuity.io/v1alpha1
kind: Warehouse
metadata:
  name: app
  namespace: nome-do-satelite-delivery
spec:
  interval: 2m0s
  subscriptions:
    - image:
        repoURL: ghcr.io/guesant/nome-da-imagem
        imageSelectionStrategy: Digest
        constraint: main
        strictSemvers: true
---
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: prod
  namespace: nome-do-satelite-delivery
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: app
      sources:
        direct: true
  promotionTemplate:
    spec:
      steps:
        - uses: argocd-update
          config:
            apps:
              - name: nome-da-application-filha
                namespace: argocd
                sources:
                  - repoURL: https://github.com/guesant/hl-infrastructure.git
                    helm:
                      images:
                        - key: caminho.do.values.para.a.tag
                          value: main@${{ imageFrom("ghcr.io/guesant/nome-da-imagem").Digest }}
```

O `Warehouse` acompanha a tag `main` pela estratégia `Digest`: cada vez que a pipeline do outro repositório publica e o digest atrás da tag muda, nasce um `Freight` novo, e a política de promoção automática o leva ao `Stage` `prod`. O passo `argocd-update` grava `main@sha256:...` como parâmetro Helm da própria `Application`, sem commit em nenhum repositório; o git continua declarando a tag base como ponto de partida, e o digest corrente fica visível em `kubectl -n argocd get application nome -o yaml` e na UI do Kargo. Se o satélite renderiza a imagem a partir de um chart, o `value` precisa produzir o formato que o campo do chart espera; renderize e confira antes de ligar.

Duas coisas acompanham esse bloco. A `Application` filha precisa carregar a anotação `kargo.akuity.io/authorized-stage: nome-do-satelite-delivery:prod`, que é a prova de que quem pode editar aquela `Application` consentiu com aquele `Stage` a editar; sem ela a promoção falha com erro explícito. E a `Application` `root` deste repositório precisa de um `ignoreDifferences` para `/spec/source/helm/parameters` dessa `Application`, como já existe para o blog em `argocd/root/application.yaml`, senão o `selfHeal` do root devolve a tag do git a cada reconciliação. Se a expressão `${{ ... }}` for escrita dentro de um template Helm deste repositório, ela precisa ser protegida como texto literal, porque o Helm tentaria interpretá-la.

Quando a imagem for publicada só com tags imutáveis `sha-<commit>` e sem tag móvel, troque a estratégia por `NewestBuild` com `allowTagsRegexes: ["^sha-[0-9a-f]{40}$"]` e use `imageFrom(...).Tag` no `value`.

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

O `Cluster` não declara `storageClass`: a classe padrão do cluster é a única que existe, `local-path` com `Retain`, e a política de admissão não é necessária porque não há outra classe a escolher. `Prune=false,Delete=false` no `Cluster` protege os dados de um erro de GitOps em dois momentos distintos: `Prune=false` faz o Argo se recusar a apagá-lo quando o arquivo some do repositório, e `Delete=false` o preserva quando a própria `Application` é apagada, porque toda `Application` daqui carrega o finalizer `resources-finalizer.argocd.argoproj.io`, que faz um `git rm` do arquivo dela levar junto tudo o que ela criou. Sem a segunda opção, remover o satélite do git apagaria o banco. O volume só vai embora por uma remoção manual e deliberada.

Este `Cluster` não tem backup contínuo em object storage: o operador `cnpg-barman-plugin` que fornecia isso foi removido do cluster de propósito. Sem ele, a perda do volume é perda total dos dados do satélite; veja [estado fora do git](estado-fora-do-git.md). Reinstalar o plugin é um pré-requisito antes de qualquer satélite novo poder declarar `spec.plugins` com `barman-cloud.cloudnative-pg.io`.

A senha do role criado por `bootstrap.initdb.owner` fica de fora do git de propósito: o CNPG gera ela sozinho e mantém num `Secret` próprio (`<nome-do-cluster>-app`, por padrão), sem passar por nenhum `SopsSecret`. Isso significa que ninguém, nem quem tem acesso a este repositório nem quem tem uma das chaves age de `.sops.yaml`, consegue ler essa senha fora do próprio cluster; só quem já tem acesso ao namespace do satélite (`kubectl get secret`) consegue. O custo é não existir rotação automatizada dela hoje: trocar a senha significa deixar o CNPG gerar uma nova (apagando o `Secret` que ele mantém) e reiniciar o que a consome, um processo manual por enquanto. Se um satélite precisar de mais de um role ou de controle explícito sobre quando a senha muda, `spec.managed.roles` é o mecanismo do CNPG pra isso, mas evite `passwordSecret` apontando pra um `SopsSecret`: a decisão deste cluster é manter toda senha de role do Postgres fora do git.

## Continue por aqui

Para entender a razão de existir dessa separação entre a aplicação raiz e os satélites, e o que cada opção de `syncPolicy` resolve, veja [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) na arquitetura. Para entender o caminho inteiro de uma imagem publicada até o pod, e o que fazer quando nada promove, veja [rollout de imagens](../arquitetura/rollout-de-imagens.md).
