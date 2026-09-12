# GitOps: root e satélites

O ArgoCD sincroniza este cluster a partir de um padrão de app-of-apps recursivo, com dois projetos (`AppProject`) que têm permissões bem diferentes.

O projeto `infra` cobre a infraestrutura definida diretamente neste repositório e tem acesso amplo: pode criar `Namespace`, `AppProject` e `Application` em qualquer escopo de cluster. É nele que vive a aplicação `root`, aplicada uma única vez pela role `bootstrap-app`, apontando para a pasta [argocd/applications](https://github.com/guesant/hl-infrastructure/tree/main/argocd/applications) com sincronização recursiva de diretório ligada. Qualquer arquivo `Application` novo colocado ali é detectado e sincronizado pelo Argo sozinho, sem nenhum passo manual.

O projeto `satellites` cobre repositórios de aplicação, como o do blog, e é deliberadamente restrito: só pode criar recursos de escopo de namespace, com uma única exceção liberada explicitamente para o tipo `StorageClass`. Uma `Application` satélite não consegue criar uma `ClusterRole` ou uma `CustomResourceDefinition`, mesmo que o operador do Argo quisesse; a permissão simplesmente não existe no projeto. Isso significa que um repositório de aplicação nunca pode, por engano ou por comprometimento, escalar para um recurso de cluster inteiro.

Cada satélite é, ele mesmo, outra `Application` com sincronização recursiva de diretório, apontando para uma pasta de GitOps dentro do outro repositório. Um commit nesse outro repositório propaga sozinho, sem que o Ansible ou este repositório precisem rodar de novo. O guia [adicionar um satélite novo](../operacional/adicionar-um-satelite.md) mostra o formato exato de um satélite.

## Por que dois projetos, e não um só

A alternativa mais simples seria um único `AppProject` com permissão ampla para tudo. O problema é que isso apagaria justamente a garantia que se quer: que um repositório de aplicação (potencialmente escrito e mantido com menos rigor de revisão do que este repositório de infraestrutura) não consiga, por acidente ou não, tocar em nada além do próprio namespace. Separar os dois projetos torna essa garantia parte da configuração do próprio ArgoCD, não uma convenção que depende de disciplina humana para se manter.
