# PostgreSQL compartilhado

O ambiente está sendo preparado para usar um único cluster CloudNativePG no
namespace `data`, com bancos separados para o portfólio e o Keycloak. Esta
mudança reduz o custo fixo de manter mais de um cluster PostgreSQL no mesmo
node, mas não mistura os dados nem as credenciais das aplicações.

## Estado atual

O cutover ainda não foi feito. Os clusters `blog-postgres` e
`keycloak-postgres` continuam sendo os bancos usados pelas aplicações. O
cluster `shared-postgres` é apenas uma preparação declarativa e não deve
receber tráfego antes da restauração e da validação dos dados.

Os manifests ficam em:

- `argocd/apps/data/shared-postgres` para o cluster, os bancos, as roles e as
  políticas de rede;
- `argocd/applications/data/shared-postgres.yaml` para o Application do Argo
  CD;
- `argocd/apps/platform/namespaces/templates/data.yaml` para o namespace.

## Isolamento lógico

O cluster compartilhado contém os bancos `portfolio` e `keycloak`. Cada banco
possui uma role própria com permissão de login. A role `portfolio` só deve ser
usada pelo Laravel e a role `keycloak` só deve ser usada pelo Keycloak. A
separação de roles evita que uma aplicação use a credencial ou o banco da
outra.

Os recursos `Database` e `DatabaseRole` são mantidos pelo CloudNativePG. O
nome do banco e da role é explícito para que o estado editorial não dependa
de convenções implícitas do bootstrap. As políticas de retenção impedem que
uma remoção acidental do recurso pelo GitOps apague o banco ou a role.

As senhas não são adicionadas ao repositório. Como o `DatabaseRole` é
namespace-scoped, os Secrets `portfolio-postgres-app` e
`keycloak-postgres-app`, ambos do tipo `kubernetes.io/basic-auth`, precisam
existir no namespace `data` antes da sincronização. Os consumidores também
precisam de Secrets locais, com a mesma credencial da role correspondente e o
host `postgres-rw.data.svc.cluster.local`. Esses Secrets serão criados pelo
fluxo SOPS durante o cutover. A mesma senha não deve ser reutilizada entre
Laravel e Keycloak.

## Rede

O `NetworkPolicy` do namespace `data` permite entrada na porta PostgreSQL
somente para:

- os pods Laravel do namespace `blog`;
- os pods Keycloak do namespace `keycloak`;
- os componentes do CloudNativePG necessários para administração e métricas.

O egress do Laravel para o cluster compartilhado também está preparado na
`CiliumNetworkPolicy`. A regra não troca o host usado pela aplicação, porque
isso só deve ocorrer durante o cutover. O acesso ao banco continua limitado à
porta `5432`.

## Ordem do cutover

O cutover é uma operação de migração, não uma simples alteração de endpoint.
Execute as etapas nesta ordem:

1. Fazer backup verificável dos bancos atuais do blog e do Keycloak.
2. Restaurar cada banco no banco correspondente do cluster compartilhado.
3. Comparar contagens, extensões, migrations, usuários e dados críticos.
4. Criar os Secrets `portfolio` e `keycloak` nos namespaces consumidores.
5. Validar Laravel e Keycloak usando o endpoint interno do cluster.
6. Trocar os hosts e referências de Secret durante a janela de mudança.
7. Executar smoke tests e observar logs, conexões, latência e erros.
8. Manter os clusters antigos intactos durante a janela de rollback.
9. Remover os clusters antigos somente depois de confirmar a restauração e o
   funcionamento contínuo.

Não aplique a troca de host antes da restauração. Também não remova PVCs,
Secrets ou clusters antigos para liberar espaço: o caminho de volta depende
justamente desses recursos.

## Falha e rollback

Se a aplicação não conectar, se uma migration falhar ou se o Keycloak não
conseguir ler seus realms, interrompa a promoção e volte temporariamente às
referências dos clusters atuais. O cluster compartilhado pode permanecer
isolado para diagnóstico, mas os dados restaurados não devem ser descartados
até a conclusão da investigação.

O cluster único reduz overhead, mas cria um domínio de falha comum. Uma falha
no node, no armazenamento local ou no operador pode afetar Laravel e Keycloak
ao mesmo tempo. Por isso, o backup externo e o teste de restauração continuam
sendo requisitos mesmo depois da consolidação.

## Referências

- [Gerenciamento declarativo de bancos no CloudNativePG](https://cloudnative-pg.io/docs/devel/declarative_database_management/)
- [Gerenciamento declarativo de roles no CloudNativePG](https://cloudnative-pg.io/docs/1.30/declarative_role_management/)
- [CloudNativePG e políticas de rede](https://cloudnative-pg.io/docs/1.30/security/networking/)
