# Resposta a incidente

Um incidente aqui é qualquer sinal de que alguém que não é o operador leu, mudou ou controla algo do cluster: um segredo que apareceu num lugar público, um commit em `main` que ninguém fez, um processo desconhecido no node, um alerta do auditd sobre arquivo de identidade. O plano abaixo é curto de propósito, porque é para ser seguido sob pressão, e cada passo aponta para o runbook que já existe.

## Conter

1. Tirar o tráfego público do ar se o blog estiver servindo algo indevido: desligar o túnel no dashboard da Cloudflare corta todo acesso externo sem tocar no node.
2. Se o comprometimento é do repositório, revogar o token do Renovate no environment `renovate` e conferir os bypasses recentes do ruleset de `main`.
3. Se é do node, isolar antes de investigar: o firewall já só aceita SSH e a API do k3s dos CIDRs do operador, então basta não reiniciar nada que apague evidência.

## Preservar evidência

Antes de corrigir, copie para fora do node o que um reboot ou uma reinstalação apagaria: o journal (`journalctl --since`), o log do auditd (`/var/log/audit/audit.log`), o audit log do API server (`/var/lib/rancher/k3s/server/logs/audit.log`) e a lista de processos e conexões (`ps auxf`, `ss -tulnp`).

## Erradicar e recuperar

Rotacione tudo que o incidente pode ter exposto, na ordem de [rotacionar credenciais](rotacionar-credenciais.md): chaves age, token do túnel, API token da Cloudflare, certificados e token do k3s. Se o node não é mais confiável, reinstale seguindo [restaurar o node](restaurar-o-node.md); o repositório e as cópias cifradas bastam para reconstruir tudo, menos os dados do Postgres, que não têm backup hoje.

## Depois

Registre o que aconteceu, a causa e o que mudou numa linha do [checklist de segurança](../arquitetura/checklist-de-seguranca.md) ou num commit com a correção.

## Exercício periódico

Uma vez por trimestre, junto com a [revisão periódica](revisao-periodica.md), simule um cenário sem executar as ações destrutivas: escolha um passo deste plano, confirme que os comandos e os links ainda funcionam e que os runbooks citados continuam corretos, e registre a data em `.config/security-review.conf`. Um plano que ninguém exercita envelhece junto com o repositório.

## Continue por aqui

[Restaurar o node do zero](restaurar-o-node.md) cobre o cenário mais severo deste plano, a reconstrução completa; [revisão periódica](revisao-periodica.md) é onde o exercício trimestral fica registrado.
