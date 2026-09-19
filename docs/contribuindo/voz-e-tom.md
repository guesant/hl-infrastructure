# Voz e tom

As [convenções de escrita](convencoes-de-escrita.md) tratam de mecânica: quando usar crase, quando usar lista, como terminar uma página. Voz e tom é sobre outra coisa, o jeito de dizer as coisas dentro dessas regras mecânicas, e varia um pouco por seção.

| Seção | Tom | Por quê |
| --- | --- | --- |
| Aprender | Didático, paciente com quem não conhece o conceito ainda | O leitor pode estar vendo o termo pela primeira vez; pressa aqui custa compreensão |
| Arquitetura | Analítico, argumentando uma decisão até o fim | O objetivo é convencer, com os fatos e as alternativas descartadas, não só afirmar |
| Operacional | Direto, imperativo, sem rodeio antes do comando | Quem está aqui já decidiu o que fazer; a página só precisa dizer como |
| Avisos e riscos | Direto ao ponto de ser seco | Um aviso hedgeado ("pode ser que em alguns casos isso cause um problema") é fácil de ignorar; um aviso direto não é |

O fio comum entre essas seções é evitar linguagem hedgeada, que soa cautelosa mas não diz nada: "pode ajudar a garantir", "em geral costuma ser uma boa prática considerar", "é importante notar que". Se uma frase é verdadeira, ela pode ser escrita como afirmação; se não é sempre verdadeira, a exceção merece ser nomeada, não escondida atrás de um advérbio de cautela.

## Antes e depois

Estes exemplos usam o texto real deste repositório como "depois"; o "antes" é uma reescrita hipotética no tom que evitamos, para deixar o contraste concreto.

Antes: "É importante notar que o campo `project` deve ser configurado corretamente para `satellites`, pois isso pode ajudar a garantir que os recursos sejam devidamente restritos ao namespace."

Depois, de [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md): "O projeto `satellites` é deliberadamente restrito: só pode criar recursos de escopo de namespace, com exceções liberadas explicitamente no `clusterResourceWhitelist` do `AppProject`: `Namespace`, `StorageClass` e o `Project` do Kargo. Uma `Application` sob esse projeto não consegue criar uma `ClusterRole` ou uma `CustomResourceDefinition`, mesmo que o operador do Argo quisesse; a permissão simplesmente não existe no projeto."

A diferença não é só de tamanho. A versão hedgeada não diz o que aconteceria se o campo estivesse errado nem por que a restrição existe; a versão real nomeia o mecanismo (a permissão não existe no projeto, não é uma convenção que alguém possa violar por descuido) e deixa explícito que as exceções liberadas são uma lista fechada e deliberada, não uma lacuna.

Antes: "Nós decidimos usar o OpenTofu ao invés de um reconciliador porque acreditamos que isso pode trazer benefícios em termos de visibilidade das mudanças, embora existam alguns tradeoffs a serem considerados."

Depois, de [OpenTofu](../arquitetura/opentofu.md): "A escolha pelo OpenTofu, e não por um reconciliador dentro do cluster, foi deliberada: `plan` legível antes de cada mudança e state explícito, ao custo de o realm só reconciliar quando o operador roda o módulo."

Aqui a diferença é nomear o custo explicitamente, no lugar de "alguns tradeoffs a serem considerados", que não diz qual é o tradeoff nem convida o leitor a julgar se ele vale a pena.

O exemplo seguinte é de outro tipo de problema: cada crase estava certa, e a frase mesmo assim não se lia. O "antes" aqui é o texto que estava publicado, não uma reescrita hipotética.

Antes, de uma versão anterior de [Ansible: as roles do bootstrap](../arquitetura/ansible.md): "com o login pelo realm `management` do Keycloak declarado em `oidc.config` (com PKCE, que o client do realm exige) (o client secret vem do `Secret` `argocd-oidc`, entregue pela `Application` `sso`, referenciado como `$argocd-oidc:clientSecret`) e uma política RBAC em que só o grupo `admins` tem papel".

Depois: "com o login pelo realm `management` do Keycloak declarado em `oidc.config`, com PKCE, que o client do realm exige; o client secret vem do `Secret` `argocd-oidc`, entregue pela `Application` `sso`, referenciado como `$argocd-oidc:clientSecret`. A mesma configuração declara uma política RBAC em que só o grupo `admins` tem papel".

Nenhum identificador saiu, porque todos são literais que alguém vai procurar no arquivo. O que mudou foi a frase em volta deles: os parênteses encadeados viraram uma oração e uma frase nova, e a enumeração que continuava depois deles ganhou um sujeito próprio. A régua para esse caso está na seção sobre crases das [convenções de escrita](convencoes-de-escrita.md): a representação literal pode ser frequente, mas não pode ser ela que sustenta a frase.

## Continue por aqui

[Normas de redação técnica](normas-de-redacao-tecnica.md) explica a origem das convenções que sustentam esse tom.
