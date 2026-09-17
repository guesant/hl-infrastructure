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

Estes dois exemplos usam o texto real deste repositório como "depois"; o "antes" é uma reescrita hipotética no tom que evitamos, para deixar o contraste concreto.

Antes: "É importante notar que o campo `project` deve ser configurado corretamente para `satellites`, pois isso pode ajudar a garantir que os recursos sejam devidamente restritos ao namespace."

Depois, de [GitOps: root e satélites](../arquitetura/gitops-root-e-satelites.md): "O projeto `satellites` é deliberadamente restrito: só pode criar recursos de escopo de namespace, com exceções liberadas explicitamente no `clusterResourceWhitelist` do `AppProject`: `Namespace`, `StorageClass` e o `Project` do Kargo. Uma `Application` sob esse projeto não consegue criar uma `ClusterRole` ou uma `CustomResourceDefinition`, mesmo que o operador do Argo quisesse; a permissão simplesmente não existe no projeto."

A diferença não é só de tamanho. A versão hedgeada não diz o que aconteceria se o campo estivesse errado nem por que a restrição existe; a versão real nomeia o mecanismo (a permissão não existe no projeto, não é uma convenção que alguém possa violar por descuido) e deixa explícito que as exceções liberadas são uma lista fechada e deliberada, não uma lacuna.

Antes: "Nós decidimos usar o OpenTofu ao invés de um reconciliador porque acreditamos que isso pode trazer benefícios em termos de visibilidade das mudanças, embora existam alguns tradeoffs a serem considerados."

Depois, de [OpenTofu](../arquitetura/opentofu.md): "A escolha pelo OpenTofu, e não por um reconciliador dentro do cluster, foi deliberada: `plan` legível antes de cada mudança e state explícito, ao custo de o realm só reconciliar quando o operador roda o módulo."

Aqui a diferença é nomear o custo explicitamente, no lugar de "alguns tradeoffs a serem considerados", que não diz qual é o tradeoff nem convida o leitor a julgar se ele vale a pena.

## Continue por aqui

[Normas de redação técnica](normas-de-redacao-tecnica.md) explica a origem das convenções que sustentam esse tom.
