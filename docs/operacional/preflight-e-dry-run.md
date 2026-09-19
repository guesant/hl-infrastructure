# Preflight e dry-run do bootstrap

Antes de aplicar qualquer coisa no node, as recipes de verificação respondem, na ordem, duas perguntas: consigo falar com a máquina certa, e o que mudaria se eu rodasse agora. Nenhuma delas altera o node.

| Recipe | Faz o quê |
| --- | --- |
| `just preflight` | confere acesso ao node, sem alterar nada |
| `just bootstrap-check` | roda o preflight e depois um dry-run completo do `site.yml` |
| `just bootstrap` | roda o preflight e aplica o `site.yml` de verdade |

A ordem entre elas não depende de disciplina de quem digita: bootstrap-check e bootstrap declaram preflight como dependência no `justfile`, e repassam a ele os mesmos argumentos, então a checagem de acesso sempre roda primeiro.

## Preflight

```bash
just preflight
```

`ansible/preflight.yml` confere os pontos da tabela abaixo antes de qualquer outra role rodar.

| Verificação | O que confirma |
| --- | --- |
| ping | conectividade básica com o host |
| shell POSIX | o usuário do inventário não usa um shell incompatível, como fish |
| família Debian | a distribuição do node é suportada |
| arquitetura | `aarch64` ou `x86_64`, as únicas para as quais k3s, Helm e cilium-cli são baixados |
| escalação de privilégio | o usuário do inventário consegue virar root |
| resumo da máquina | distribuição, kernel, memória, controladores de cgroup disponíveis |

O inventário conecta como root, então a escalação nunca pede senha; se ela falhar, o preflight diz que o `ansible_user` precisa ser root. Cada asserção dessas existe para o erro aparecer aqui e não no meio do bootstrap: um usuário com fish como shell de login, por exemplo, quebraria em alguma role qualquer, porque o Ansible monta comandos que o fish não interpreta, e a mensagem no meio da execução não diria isso.

Todo argumento extra passado às três recipes vai direto para o `ansible-playbook`, então as flags de filtro abaixo funcionam como de costume.

| Flag | Efeito |
| --- | --- |
| `--limit` | restringe a execução a um subconjunto de hosts do inventário |
| `--tags` | roda só as roles marcadas com a tag indicada |
| `--skip-tags` | roda tudo menos as roles marcadas com a tag indicada |

Cada role em `site.yml` tem uma tag com o próprio nome, declarada ao lado dela em `ansible/site.yml`, na ordem em que elas rodam; é lá que se confere o nome exato antes de filtrar. Os exemplos abaixo aplicam só o firewall, ou preveem tudo menos a role que pode reiniciar o node:

```bash
just bootstrap --tags firewall
just bootstrap-check --skip-tags k3s
```

Um atalho diferente age sozinho, sem você pedir: as roles cilium e argocd pulam a comparação com o cluster quando a versão do chart e os values não mudaram desde o último apply. `-e chart_reconcile=true` força essa comparação, o que é o certo depois de uma mudança manual no cluster. Veja [Ansible: as roles do bootstrap](../arquitetura/ansible.md) para o que cada atalho deixa de ver.

## Dry-run

```bash
just bootstrap-check
```

Roda o preflight e depois `site.yml` com `--check --diff`.

Cada role sabe o que consegue prever num node que ainda não tem k3s: a role `k3s` registra se o binário já existe, e quando não existe sob esse modo de verificação, uma role dedicada (`check_mode_gate`) avisa que nada que fale com o cluster pode ser conferido ainda. As roles seguintes pulam o bloco que depende da API, em vez de falhar com um erro sem relação com o que se queria saber.

O mesmo vale para o firewalld e para cada serviço systemd: uma unit que só seria instalada numa execução real não é iniciada em modo de verificação.

Num node que já tem o cluster, o dry-run é completo: cada chart é renderizado e enviado ao API server com `--dry-run=server`, então a saída diz se cada recurso ficaria configured ou permaneceria unchanged, com o mesmo apply server-side da execução real, sem gravar nada.

É a forma de ver o efeito de uma versão nova em `versions.yml` antes de aplicá-la. O atalho das roles cilium e argocd continua valendo neste modo, então um dry-run silencioso sobre essas duas pode significar só que elas pularam a comparação; `-e chart_reconcile=true` a força e devolve o diff real.

## Continue por aqui

Depois de um dry-run limpo, [primeiro bootstrap](primeiro-bootstrap.md) descreve a execução real, e [Ansible: as roles do bootstrap](../arquitetura/ansible.md) explica o que cada role verifica antes de agir.
