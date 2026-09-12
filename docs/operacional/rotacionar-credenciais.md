# Rotacionar credenciais do k3s

Duas credenciais do k3s têm rotina de rotação própria, cada uma num playbook separado de `site.yml`, porque as duas interrompem o cluster por alguns segundos e nunca devem acontecer como efeito colateral de um bootstrap.

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

## Continue por aqui

[Estado fora do git](estado-fora-do-git.md) lista onde cada credencial vive e o que se perde com ela; o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz por que o kubeconfig é o ativo mais sensível da máquina do operador.
