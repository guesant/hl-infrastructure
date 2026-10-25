# PostgreSQL compartilhado

O cluster CloudNativePG único fica no namespace `data`. Ele atende Atlas e
Keycloak, mantendo bancos, roles e credenciais separados.

## Recursos declarados

O chart em `argocd/apps/data/shared-postgres` declara o cluster, os bancos, as
roles de aplicação e as políticas de rede. Os manifests do `SopsSecret` ficam
em `argocd/apps/secrets/data/postgres`; os consumidores são configurados em
`argocd/apps/secrets/data/postgres-consumers`.

| Banco | Roles de aplicação | Secrets de origem | Namespace consumidor |
| --- | --- | --- | --- |
| `atlas` | `atlas_a`, `atlas_b` | `atlas-postgres-app-a`, `atlas-postgres-app-b` | `atlas` |
| `keycloak` | `keycloak_a`, `keycloak_b` | `keycloak-postgres-app-a`, `keycloak-postgres-app-b` | `keycloak` |

As roles proprietárias `atlas` e `keycloak` não aceitam login. Cada role de
aplicação herda os privilégios da role proprietária correspondente, sem
compartilhar credenciais entre os bancos. Os recursos `Database` e
`DatabaseRole` usam retenção para evitar que um prune acidental apague dados.

## Credenciais

As senhas dos slots A/B são cifradas no Git por SOPS. O `ClusterSecretStore`
`data-secrets` lê somente os Secrets de Atlas, Keycloak, Silo e Redis; os
`ExternalSecret` criam os Secrets necessários nos namespaces consumidores.
Atlas e Keycloak usam atualmente o slot `a`.

A rotação prepara o slot inativo, valida a conexão antes da ativação e mantém
o slot anterior durante a janela de rollback. Os comandos executam dentro da
imagem Docker do repositório:

```bash
just postgres-rotation-status atlas
just postgres-rotation-prepare atlas b
just postgres-rotation-activate atlas b
```

O mesmo procedimento vale para `keycloak`. Depois de confirmar a conexão e
aguardar a janela operacional, `just postgres-rotation-retire atlas a`
desabilita o login do slot antigo sem apagar sua definição. Os comandos não
imprimem senhas nem o conteúdo dos Secrets.

## Rede

A porta `5432` aceita conexões dos pods LinkAce no namespace `atlas`, do
Keycloak no namespace `keycloak` e dos componentes do CloudNativePG usados
para administração e métricas. O acesso é limitado ao tráfego interno do
cluster.

O namespace `blog` não consome mais este PostgreSQL. O cluster mantém uma
instância no Raspberry Pi; a retenção de seu volume protege contra a exclusão
acidental do recurso, mas não substitui uma cópia de segurança externa.

## Referências

- [Gerenciamento declarativo de bancos no CloudNativePG](https://cloudnative-pg.io/docs/devel/declarative_database_management/)
- [Gerenciamento declarativo de roles no CloudNativePG](https://cloudnative-pg.io/docs/1.30/declarative_role_management/)
- [CloudNativePG e políticas de rede](https://cloudnative-pg.io/docs/1.30/security/networking/)
