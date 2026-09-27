# Reconstruir um cluster de nó único

Um cluster com vários managers sobrevive à perda de um deles porque os outros continuam servindo a API enquanto o nó perdido é substituído. Um cluster de nó único não tem essa rede de proteção: a perda do host físico, seja por falha de disco, de hardware ou do provedor que o hospeda, é a perda do cluster inteiro, e a resposta é reconstruir o ambiente em uma máquina nova.

## Restaurar a partir do snapshot do etcd

A primeira estratégia usa o último snapshot do datastore, descrito em [Backup do etcd, do CloudNativePG e da chave age](../aprender/backup-do-etcd-cnpg-e-chave-age.md), para recriar o estado que a API Kubernetes tinha no momento daquele snapshot. Isso inclui recursos que talvez nunca tenham sido declarados no Git, como uma mudança manual feita diretamente no cluster.

Essa fidelidade ao estado observado é também a limitação da estratégia: ela recupera o que estava lá, mesmo o que não deveria estar, e sua qualidade depende da idade do snapshot. Um snapshot de doze horas atrás implica perder qualquer mudança feita nas últimas doze horas. O RPO real é a idade do snapshot.

## Reconstruir via GitOps

A segunda estratégia ignora o snapshot e reexecuta o bootstrap inteiro numa máquina nova. A distribuição Kubernetes é instalada do zero, o repositório GitOps é conectado e o controlador reconcilia o cluster a partir do que está declarado no Git.

O resultado é exatamente o que o Git descreve. Recursos criados manualmente fora do fluxo GitOps não voltam, porque nunca foram declarados. Essa estratégia é preferível quando o repositório está atualizado ou quando o snapshot está indisponível, corrompido ou velho demais para o RPO aceito.

## Limite da reconstrução

Nenhuma das duas estratégias restaura volumes persistentes automaticamente. Essa recuperação segue o backup próprio de cada serviço.

[Recuperar a capacidade de decifrar segredos](recuperacao-de-segredos.md) trata da chave e do material de bootstrap, que são uma responsabilidade separada.
