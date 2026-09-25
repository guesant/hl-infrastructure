# PostgreSQL compartilhado

O ambiente usa um único cluster CloudNativePG no namespace `data`, com bancos
separados para o portfólio e o Keycloak. Essa escolha reduz o custo fixo de
manter mais de um cluster PostgreSQL no mesmo node, mas não mistura os dados
nem as credenciais das aplicações.

## Estado atual

O chart declara a transição das credenciais legadas para slots A/B. O slot `a`
está ativo para Laravel e Keycloak, e os consumidores já leem os Secrets
`portfolio-postgres-app-a` e `keycloak-postgres-app-a`. O slot `b` permanece
preparado para rollback ou para a próxima rotação.

Os manifests ficam em:

- `argocd/apps/data/shared-postgres` para o cluster, os bancos, as roles, os
  Secrets cifrados, os `ExternalSecret` dos consumidores e as políticas de
  rede;
- `argocd/applications/data/shared-postgres.yaml` para o Application do Argo
  CD;
- `argocd/apps/platform/namespaces/templates/data.yaml` para o namespace.

## Isolamento lógico

O cluster compartilhado contém os bancos `portfolio` e `keycloak`. As roles
`portfolio` e `keycloak` permanecem como proprietárias dos respectivos bancos
e objetos, mas deixam de ser credenciais de aplicação quando a transição A/B é
ativada. Elas são roles sem login. O Laravel usa `portfolio_a` ou
`portfolio_b`, e o Keycloak usa `keycloak_a` ou `keycloak_b`.

Cada role de aplicação pertence à role proprietária correspondente por
`inRoles`. Isso preserva os privilégios necessários sem dar ao Laravel acesso
ao banco do Keycloak ou o contrário.

Os recursos `Database` e `DatabaseRole` são mantidos pelo CloudNativePG. O
nome do banco e da role é explícito para que o estado editorial não dependa
de convenções implícitas do bootstrap. As políticas de retenção impedem que
uma remoção acidental do recurso pelo GitOps apague o banco ou a role.

As senhas ficam cifradas no Git por SOPS. No namespace `data` existem os
Secrets `portfolio-postgres-app-a`, `portfolio-postgres-app-b`,
`keycloak-postgres-app-a` e `keycloak-postgres-app-b`, todos do tipo
`kubernetes.io/basic-auth`. Cada senha é própria da role correspondente e não
é reutilizada entre Laravel e Keycloak.

Os `ExternalSecret` dos namespaces `blog` e `keycloak` são gerenciados pelo
chart `shared-postgres`. Eles sempre criam os mesmos Secrets locais, mas leem
o slot indicado por `rotation.*.activeSlot`. Assim, a troca da credencial é
uma alteração declarativa de uma única fonte, sem editar os Deployments.

Depois da validação do cutover, os Secrets de origem legados foram removidos.
Os consumidores mantêm os mesmos nomes de Secret locais e leem somente o slot
ativo A ou B.

O label `cnpg.io/reload: "true"` permite que o CloudNativePG aplique a nova
senha assim que o Secret do slot for alterado.

O `ClusterSecretStore` `data-secrets` só lê os quatro Secrets dos slots A/B. A
permissão dos consumidores continua limitada aos namespaces previstos.

## Rotação A/B

As operações são executadas dentro da imagem Docker de ferramentas:

```bash
just postgres-rotation-prepare portfolio a
just postgres-rotation-status portfolio
just postgres-rotation-activate portfolio a
just postgres-rotation-prepare portfolio b
just postgres-rotation-activate portfolio b
just postgres-rotation-retire portfolio a
```

O mesmo fluxo vale para `keycloak`. O slot preparado deve ser validado com um
teste de conexão dentro do cluster antes de ser ativado. O teste não imprime
senha, connection string ou conteúdo de Secret.

O comando `prepare` gera uma senha forte, cifra o novo Secret e torna o slot
testável. O comando `activate` altera o slot consumido pelos `ExternalSecret`.
O ESO atualiza o Secret local e o Reloader reinicia os workloads que recebem a
credencial por variável de ambiente. O comando `retire` deve ser executado
somente depois de uma janela operacional de 30 minutos. Ele desabilita o login
do slot anterior, mas mantém sua definição para rollback e reutilização.

O Laravel tem réplicas suficientes para um rollout gradual. O Keycloak possui
uma réplica e pode ter uma breve janela de readiness durante a troca da
variável de ambiente. A sobreposição A/B elimina a falha causada por uma
credencial antiga ser revogada antes de todos os processos receberem a nova.

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
4. Criar e testar os quatro slots A/B no namespace `data`.
5. Validar Laravel e Keycloak usando o endpoint interno do cluster.
6. Ativar os slots individualmente através do valor GitOps correspondente.
7. Executar smoke tests e observar logs, conexões, latência e erros durante 30
   minutos.
8. Aposentar o slot anterior somente depois da validação.
9. Remover os Secrets legados apenas depois de confirmar que nenhum recurso os
   referencia.

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
