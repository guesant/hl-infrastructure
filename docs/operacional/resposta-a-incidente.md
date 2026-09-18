# Resposta a incidente

Um incidente aqui é qualquer sinal de que alguém que não é o operador leu, mudou ou controla algo do cluster: um segredo que apareceu num lugar público, um commit em `main` que ninguém fez, um processo desconhecido no node, um alerta do auditd sobre arquivo de identidade. Esse último sinal é concreto: a role `auditd` instala regras que observam `/etc/passwd`, `/etc/shadow`, os sudoers e os diretórios de credenciais e TLS do k3s, então uma escrita em qualquer um deles aparece no log com a chave `identity` ou `k3s_credentials`. O plano abaixo é curto de propósito, porque é para ser seguido sob pressão, e cada passo aponta para o runbook que já existe.

## Conter

1. Tirar o tráfego público do ar se o blog estiver servindo algo indevido: desligar o túnel no dashboard da Cloudflare corta todo acesso externo sem tocar no node.
2. Se o comprometimento é do repositório, revogar o token do Renovate no environment `renovate` e conferir os bypasses recentes do ruleset de `main`.
3. Se é do node, isolar antes de investigar: o firewall já só aceita SSH e a API do k3s dos CIDRs do operador, então basta não reiniciar nada que apague evidência.

## Preservar evidência

Antes de corrigir, copie para fora do node o que um reboot ou uma reinstalação apagaria: o journal (`journalctl --since`), o log do auditd (`/var/log/audit/audit.log`), o audit log do API server (`/var/lib/rancher/k3s/server/logs/audit.log`) e a lista de processos e conexões (`ps auxf`, `ss -tulnp`). O audit log do API server rotaciona sozinho, limitado a trinta dias, dez arquivos e cem megabytes cada, então a janela para copiá-lo é menor do que parece, e uma reinstalação do node leva o resto junto. Vale o esforço porque a política de auditoria do k3s registra em nível de metadados toda leitura de `Secret`, `ConfigMap` e `SopsSecret`, e guarda requisição e resposta inteiras nas mudanças de RBAC e nos `pods/exec`, que é exatamente onde um acesso indevido deixa rastro.

## Erradicar e recuperar

Rotacione tudo que o incidente pode ter exposto, na ordem de [rotacionar credenciais](rotacionar-credenciais.md): chaves age, token do túnel, API token da Cloudflare, certificados e token do k3s. A chave age do node vem antes das outras nessa lista porque é ela que decifra todo `SopsSecret`, e as rotações seguintes reescrevem justamente esses arquivos. Se o node não é mais confiável, reinstale seguindo [restaurar o node](restaurar-o-node.md); o repositório e as cópias cifradas bastam para reconstruir tudo, menos os dados do Postgres, que não têm backup hoje. O que se perde ali é o banco do Keycloak, ou seja, os usuários de cada realm com suas senhas e segundos fatores, que terão de ser criados de novo com `just keycloak-user`.

## Depois

Registre o que aconteceu, a causa e o que mudou numa linha do [checklist de segurança](../arquitetura/checklist-de-seguranca.md) ou num commit com a correção. Esse registro é o que sobra do incidente no repositório: `.config/security-review.conf` guarda só a data da última revisão, nunca o que foi encontrado nela. Se a correção mudou uma decisão de desenho, e não apenas um valor, ela pertence também à página de arquitetura correspondente, para a próxima pessoa não refazer o mesmo caminho.

## Exercício periódico

Uma vez por trimestre, junto com a [revisão periódica](revisao-periodica.md), simule um cenário sem executar as ações destrutivas: escolha um passo deste plano, confirme que os comandos e os links ainda funcionam e que os runbooks citados continuam corretos, e registre a data em `.config/security-review.conf`. `just lint-security-review` lê o `last_review` desse arquivo e avisa quando ele passa dos noventa dias declarados ali, o que dá ao exercício um prazo visível em vez de uma intenção. Um plano que ninguém exercita envelhece junto com o repositório.

## Continue por aqui

[Restaurar o node do zero](restaurar-o-node.md) cobre o cenário mais severo deste plano, a reconstrução completa; [revisão periódica](revisao-periodica.md) é onde o exercício trimestral fica registrado.
