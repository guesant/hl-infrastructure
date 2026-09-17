# Preflight e dry-run do bootstrap

Antes de aplicar qualquer coisa no node, as recipes de verificação respondem, na ordem, "consigo falar com a máquina certa" e "o que mudaria se eu rodasse agora". Nenhuma delas altera o node.

## Preflight

```bash
just preflight
```

Roda `ansible/preflight.yml`: ping, shell POSIX para o usuário do inventário, família Debian, arquitetura `aarch64` ou `x86_64` (as únicas para as quais k3s, Helm e cilium-cli são baixados), escalação de privilégio funcionando e um resumo da máquina (distribuição, kernel, memória, controladores de cgroup disponíveis). O inventário conecta como `root`, então a escalação nunca pede senha; se ela falhar, o preflight diz que o `ansible_user` precisa ser `root`.

Todo argumento extra passado a `preflight`, `bootstrap-check` e `bootstrap` vai direto para o `ansible-playbook`, então `--limit` e `--tags` funcionam como de costume. Cada role em `site.yml` tem uma tag com o próprio nome, então `just bootstrap --tags firewall` aplica só o firewall e `just bootstrap-check --skip-tags k3s` prevê tudo menos a role que pode reiniciar o node. As roles `cilium` e `argocd` pulam a comparação com o cluster quando a versão do chart e os values não mudaram desde o último apply; `-e chart_reconcile=true` força essa comparação, o que é o certo depois de uma mudança manual no cluster. Veja [Ansible: as roles do bootstrap](../arquitetura/ansible.md) para o que cada atalho deixa de ver.

## Dry-run

```bash
just bootstrap-check
```

Roda o preflight e depois `site.yml` com `--check --diff`. Cada role sabe o que consegue prever num node que ainda não tem k3s: a role `k3s` registra se o binário já existe e, quando não existe sob `--check`, a role `check_mode_gate` avisa que nada que fale com o cluster pode ser conferido ainda e as roles seguintes pulam o bloco que depende da API, em vez de falhar com um erro sem relação com o que se queria saber. O mesmo vale para o firewalld e para cada serviço systemd: uma unit que só seria instalada numa execução real não é iniciada em modo de verificação.

Num node que já tem o cluster, o dry-run é completo: cada chart é renderizado e enviado ao API server com `--dry-run=server`, então a saída diz `configured` ou `unchanged` por recurso com o mesmo apply server-side da execução real, sem gravar nada. É a forma de ver o efeito de uma versão nova em `versions.yml` antes de aplicá-la.

## Continue por aqui

Depois de um dry-run limpo, [primeiro bootstrap](primeiro-bootstrap.md) descreve a execução real, e [Ansible: as roles do bootstrap](../arquitetura/ansible.md) explica o que cada role verifica antes de agir.
