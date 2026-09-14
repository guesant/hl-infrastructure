# Rotacionar credenciais

Três credenciais têm rotina de rotação própria, cada uma num playbook separado de `site.yml`: duas do k3s, que interrompem o cluster por alguns segundos, e a chave age do sops-secrets-operator, que não interrompe nada mas precisa do passo extra de resincronizar `.sops.yaml`. Nenhuma das três deve acontecer como efeito colateral de um bootstrap.

## Certificados

```bash
just rotate-certs -K
```

Para o k3s, roda `k3s certificate rotate`, sobe de novo, espera o API server responder e traz o kubeconfig novo para `ansible/kubeconfig`. O kubeconfig anterior deixa de funcionar no mesmo instante, então qualquer outra cópia dele (em outra máquina, num CI) precisa ser substituída. Os certificados do k3s valem um ano e o próprio k3s os renova ao reiniciar quando faltam menos de 90 dias; esta rotina é para rotação deliberada, como depois de um kubeconfig exposto.

## Token de join

```bash
just rotate-token -K
```

Lê o token atual em `/var/lib/rancher/k3s/server/token`, gera um novo com `openssl rand`, roda `k3s token rotate` e reinicia o k3s. Num cluster de um nó só o token não é usado por ninguém depois da instalação, então rotacioná-lo custa só o restart; vale fazer se o node foi clonado ou se o token apareceu em algum log.

## Chave age do node

Rotacionar essa chave é em duas fases, porque `.sops.yaml` e o `Secret` do node precisam ficar consistentes o tempo todo, nunca um sem o outro:

```bash
just rotate-age-key -K
```

Isso gera uma identidade nova, **acrescenta** ela ao `keys.txt` do `Secret` (a antiga continua lá) e reinicia o sops-secrets-operator; nenhum `SopsSecret` para de decifrar nesse meio-tempo, porque `age` tenta cada identidade do arquivo até uma funcionar. Em seguida:

```bash
just sops-recipients sync-node
just sops-sync
```

O primeiro escreve a chave pública nova em `.sops.yaml`; revise o diff e commite. O segundo recifra todo `SopsSecret` já commitado para os destinatários atuais. Só depois disso, com a chave nova já sendo a única referenciada em `.sops.yaml` e todo segredo já recifrado, feche a rotação removendo a identidade antiga:

```bash
just rotate-age-key -K -e sops_age_key_prune=true
```

Rodar `just rotate-age-key` sem a variável de novo, antes de prunar a antiga, só adiciona mais uma identidade; nada quebra, mas também não avança a rotação sozinho.

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
