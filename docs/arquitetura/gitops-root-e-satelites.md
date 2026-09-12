# GitOps: root e satélites

O ArgoCD sincroniza este cluster a partir de um padrão de app-of-apps recursivo, com dois projetos (`AppProject`) que têm permissões bem diferentes.

O projeto `infra` cobre a infraestrutura definida diretamente neste repositório e tem acesso amplo: pode criar `Namespace`, `AppProject` e `Application` em qualquer escopo de cluster. É nele que vive a aplicação `root`, aplicada uma única vez pela role `bootstrap-app`, apontando para a pasta [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications) com sincronização recursiva de diretório ligada. Qualquer arquivo `Application` novo colocado ali é detectado e sincronizado pelo Argo sozinho, sem nenhum passo manual.

O projeto `satellites` cobre repositórios de aplicação, como o do blog, e é deliberadamente restrito: só pode criar recursos de escopo de namespace, com uma única exceção liberada explicitamente para o tipo `StorageClass`. Uma `Application` satélite não consegue criar uma `ClusterRole` ou uma `CustomResourceDefinition`, mesmo que o operador do Argo quisesse; a permissão simplesmente não existe no projeto. Isso significa que um repositório de aplicação nunca pode, por engano ou por comprometimento, escalar para um recurso de cluster inteiro.

Cada satélite é, ele mesmo, outra `Application` com sincronização recursiva de diretório, apontando para uma pasta de GitOps dentro do outro repositório. Um commit nesse outro repositório propaga sozinho, sem que o Ansible ou este repositório precisem rodar de novo. O guia [adicionar um satélite novo](../operacional/adicionar-um-satelite.md) mostra o formato exato de um satélite.

## Como a pasta de applications é organizada

Dentro de `argocd/applications`, cada subpasta corresponde a uma camada, e a camada define a onda de sincronização (`argocd.argoproj.io/sync-wave`) que todo arquivo dentro dela carrega. O Argo aplica as ondas em ordem crescente e só avança para a próxima quando todos os recursos da onda anterior estão saudáveis, então a camada é o que garante que um satélite nunca sincronize antes de uma dependência de plataforma que ele precise.

| Pasta | Onda | O que vive ali |
| --- | --- | --- |
| `platform/` | `0` | Recursos de plataforma que os satélites consomem: backup de banco, notificações, políticas |
| `satellites/` | `10` | Uma `Application` por repositório de aplicação, no projeto `satellites` |

A distância entre as ondas é deliberada: sobra espaço para inserir uma camada intermediária no futuro sem renumerar o que já existe.

## A política de sincronização padrão

Todo `Application` deste repositório, o root incluído, carrega o mesmo bloco de `syncPolicy`, e o modelo em [adicionar um satélite novo](../operacional/adicionar-um-satelite.md) já vem com ele. Cada opção resolve um problema concreto do Argo em operação automática.

`ServerSideApply=true` faz o Argo aplicar por server-side apply, o mesmo modo que as roles Ansible usam nos charts, o que evita o limite de tamanho da annotation `last-applied-configuration` em CRDs grandes e deixa o Argo dono só dos campos que ele declara. `FailOnSharedResource=true` falha a sincronização se dois `Application` tentarem gerenciar o mesmo recurso, em vez de deixar os dois brigarem indefinidamente por ele. `PruneLast=true` adia a remoção de recursos que saíram do git para depois que tudo o mais da sincronização está saudável, então uma migração que cria o novo antes de apagar o velho não fica sem o velho no meio do caminho. `PrunePropagationPolicy=foreground` faz a remoção esperar os dependentes sumirem (um `Deployment` só é dado como removido depois dos seus pods), o que torna o resultado de uma sincronização observável de verdade.

O bloco `retry` com backoff (5 s, dobrando, até 3 min, cinco tentativas) cobre o caso comum de uma sincronização falhar só porque um webhook de admissão ou uma CRD ainda estava subindo; sem ele, a `Application` fica em erro até alguém clicar em sync. `allowEmpty: false` impede que um diretório vazio por engano (um `git mv` mal feito, uma branch errada) apague tudo o que a `Application` gerencia. `revisionHistoryLimit: 3` mantém só as três últimas revisões para rollback, o suficiente para desfazer uma sincronização ruim sem acumular histórico no estado do Argo.

## Por que dois projetos, e não um só

A alternativa mais simples seria um único `AppProject` com permissão ampla para tudo. O problema é que isso apagaria justamente a garantia que se quer: que um repositório de aplicação (potencialmente escrito e mantido com menos rigor de revisão do que este repositório de infraestrutura) não consiga, por acidente ou não, tocar em nada além do próprio namespace. Separar os dois projetos torna essa garantia parte da configuração do próprio ArgoCD, não uma convenção que depende de disciplina humana para se manter.
