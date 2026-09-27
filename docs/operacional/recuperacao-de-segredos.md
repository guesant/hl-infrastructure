# Recuperar a capacidade de decifrar segredos

Restaurar um snapshot do etcd recupera os Secrets do Kubernetes que existiam naquele momento. Isso não recupera a capacidade de sincronizar segredos novos nem de decifrar arquivos cifrados no repositório GitOps.

## Material crítico

Quando a estratégia é SOPS com chaves age, o material crítico é a chave privada guardada fora do cluster. A validação real não é confirmar que o operator está `Running`, mas decifrar um arquivo conhecido com a chave restaurada.

Outras estratégias têm materiais próprios:

- Sealed Secrets depende da chave do controller.
- Um operator de segredos externos depende da identidade e do backend configurado.
- Um cofre interno, como o OpenBao, pode exigir chaves de desbloqueio e quórum.

Reinstalar o componente não basta, porque ele começa sem o material que lhe dava capacidade de decifrar ou autenticar no backend externo.

## Validação

A causa mais comum de nada sincronizar depois da reinstalação é o material de bootstrap ausente ou incorreto. Recupere a chave externa e teste um arquivo cifrado conhecido antes de investigar rede, permissões ou o estado do operator.

[Reconstruir um cluster de nó único](reconstrucao-de-cluster-single-node.md) trata da recuperação do estado do Kubernetes.
