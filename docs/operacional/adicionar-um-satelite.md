# Adicionar um satélite novo

Um satélite é uma `Application` do ArgoCD que aponta para a pasta de GitOps de outro repositório, dentro do projeto `satellites`. A aplicação raiz em [argocd/root](https://github.com/guesant/hl-infrastructure/tree/main/argocd/root) sincroniza sozinha tudo que existir dentro de [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications), então registrar um satélite novo é só adicionar um arquivo ali; nenhum passo manual no cluster é necessário.

Use o satélite existente, `blog-satellite.yaml`, como modelo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nome-do-satelite
  namespace: argocd
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
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

O `project: satellites` é obrigatório: esse projeto do Argo está restrito a recursos de namespace, com uma única exceção liberada para o tipo `StorageClass`. Um satélite não pode criar `ClusterRole`, `CustomResourceDefinition` ou qualquer outro recurso de escopo de cluster; se o outro repositório precisar disso, esse recurso pertence a este repositório, não a um satélite.

O caminho em `source.path` deve apontar para uma pasta que contenha só os objetos de controle do Argo (`Application`, `ImageUpdater` e afins) daquele outro repositório, não os manifestos da aplicação em si; quem interpreta esses objetos de controle e sincroniza os manifestos de verdade é o Argo, recursivamente, a partir dali.

Depois de commitar o arquivo novo e dar push em `main` deste repositório, o Argo detecta a mudança sozinho no próximo ciclo de sincronização (por padrão, a cada três minutos) e cria a aplicação. Confirme com:

```bash
kubectl -n argocd get applications
```

## Continue por aqui

Para entender a razão de existir dessa separação entre a aplicação raiz e os satélites, veja [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md) na arquitetura.
