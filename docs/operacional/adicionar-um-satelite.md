# Adicionar um satélite novo

Um satélite é uma `Application` do ArgoCD que aponta para a pasta de GitOps de outro repositório, dentro do projeto `satellites`. A aplicação raiz em [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root) sincroniza sozinha tudo que existir dentro de [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications), então registrar um satélite novo é só adicionar um arquivo em `argocd/applications/satellites/`; nenhum passo manual no cluster é necessário.

Use o satélite existente, `satellites/blog-satellite.yaml`, como modelo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nome-do-satelite
  namespace: argocd
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

O `project: satellites` é obrigatório: esse projeto do Argo está restrito a recursos de namespace, com uma única exceção liberada para o tipo `StorageClass`. Um satélite não pode criar `ClusterRole`, `CustomResourceDefinition` ou qualquer outro recurso de escopo de cluster; se o outro repositório precisar disso, esse recurso pertence a este repositório, não a um satélite.

A onda `10` e o bloco `syncPolicy` são os mesmos de todo `Application` daqui, e [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) explica o que cada opção resolve. Copie o bloco inteiro; um satélite sem `retry`, por exemplo, fica travado em erro na primeira vez que uma CRD demorar a subir.

O caminho em `source.path` deve apontar para uma pasta que contenha só os objetos de controle do Argo (`Application`, `ImageUpdater` e afins) daquele outro repositório, não os manifestos da aplicação em si; quem interpreta esses objetos de controle e sincroniza os manifestos de verdade é o Argo, recursivamente, a partir dali.

Depois de commitar o arquivo novo e dar push em `main` deste repositório, o Argo detecta a mudança sozinho no próximo ciclo de sincronização (por padrão, a cada três minutos) e cria a aplicação. Confirme com:

```bash
kubectl -n argocd get applications
```

## O que o outro repositório precisa declarar

Os `Application` filhos, dentro da pasta de GitOps do outro repositório, devem repetir o mesmo bloco de `syncPolicy` acima. A onda neles é livre, porque o Argo só compara ondas entre irmãos da mesma `Application` pai.

### Atualização automática de imagem

O ArgoCD Image Updater já roda no cluster e é configurado por um recurso `ImageUpdater`, que fica na mesma pasta de objetos de controle do outro repositório, ao lado dos `Application` filhos:

```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: nome-do-satelite
  namespace: argocd
spec:
  writeBackConfig:
    method: argocd
  applicationRefs:
    - namePattern: nome-da-application-filha
      images:
        - alias: app
          imageName: ghcr.io/guesant/nome-da-imagem
          commonUpdateSettings:
            updateStrategy: newest-build
            allowTags: regexp:^sha-[0-9a-f]{40}$
```

A combinação de `newest-build` com `allowTags` restrito a `sha-<commit>` é a que este cluster adota: a pipeline do outro repositório publica uma tag imutável por commit, e o Image Updater escolhe sempre a mais recente delas, ignorando `latest`, `main` ou qualquer tag que possa mudar de conteúdo. O resultado é que a imagem em execução sempre aponta para um commit identificável, sem precisar de digest explícito. `method: argocd` grava a mudança como parâmetro da própria `Application`, sem commit no repositório; o git continua declarando a tag base, e a tag corrente fica visível em `kubectl -n argocd get application nome -o yaml`.

Quando a imagem só tem uma tag móvel, a alternativa é `updateStrategy: digest`, que acompanha essa tag e troca a imagem sempre que o digest por trás dela muda.

### Um banco Postgres

O operador CloudNativePG e o plugin barman-cloud já estão instalados. Um satélite que precisa de banco declara o próprio `Cluster` no próprio namespace; o formato de referência é este:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  namespace: nome-do-namespace
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
spec:
  instances: 1
  storage:
    size: 5Gi
  managed:
    roles:
      - name: app
        ensure: present
        login: true
        passwordSecret:
          name: postgres-app
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: app
  namespace: nome-do-namespace
spec:
  cluster:
    name: postgres
  name: app
  owner: app
  databaseReclaimPolicy: retain
```

Três escolhas ali protegem os dados de um erro de GitOps. `Prune=false` no `Cluster` faz o Argo se recusar a apagá-lo, mesmo que o arquivo suma do repositório; o volume só vai embora por uma remoção manual e deliberada. `databaseReclaimPolicy: retain` faz o mesmo para o `Database`: remover o objeto do git tira o banco da gestão do operador, mas não roda `DROP DATABASE`. E `managed.roles` com `passwordSecret` deixa a senha num `Secret` que o satélite entrega selado (`SealedSecret`), em vez de deixar o operador gerar uma que ninguém versiona.

## Continue por aqui

Para entender a razão de existir dessa separação entre a aplicação raiz e os satélites, e o que cada opção de `syncPolicy` resolve, veja [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) na arquitetura. Para duas armadilhas reais do Image Updater que travam a atualização de imagem em silêncio, veja [rollout de imagens](../arquitetura/rollout-de-imagens.md).
