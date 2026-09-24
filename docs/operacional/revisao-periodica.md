# Revisão periódica de permissões e exposição

Os gates de CI conferem o que está no git, mas não enxergam o que mudou fora dele nem o que ficou velho sem ninguém notar: uma porta que alguém abriu à mão no firewall, um token com permissão demais, uma `ClusterRole` que um chart novo trouxe. Esta revisão existe para isso, e o prazo dela é declarado em [.config/security-review.conf](https://github.com/guesant/hl-infrastructure/blob/main/.config/security-review.conf).

O job `secret-age` da CI avisa num push quando a última revisão passou do prazo e falha na execução agendada, então a revisão não depende de alguém lembrar.

## O que conferir

A revisão é uma leitura, não uma mudança. Cada achado vira uma linha no [checklist de segurança](../arquitetura/checklist-de-seguranca.md) ou uma correção no repositório, e só então a data é atualizada. Consertar no meio da revisão atrapalha as duas coisas, porque muda o alvo enquanto ele ainda está sendo medido e faz perder o registro do que estava errado; anotar primeiro e corrigir depois preserva as duas informações.

1. Exposição do node: `firewall-cmd --permanent --list-all-zones` no Pi deve mostrar só o que a role `firewall` declara. A reconciliação da role remove o resto, mas um item novo que ela recuse remover por passar do teto aparece aqui primeiro.
2. Serviços escutando: `ss -tulnp` no Pi, procurando qualquer processo novo fora do k3s, do Cilium e do SSH.
3. Contas e chaves: `awk -F: '$2 !~ /^[!*]/' /etc/shadow` não deve listar ninguém, e `/root/.ssh/authorized_keys` deve ter só a chave do operador.
4. RBAC do cluster: as `ClusterRole` com curinga em verbos, recursos ou grupos de API, comparadas com as justificadas no checklist; qualquer uma nova precisa de justificativa ou de correção.
5. Tokens externos: as permissões do API token da Cloudflare, do token do Renovate e das chaves age em `.sops.yaml`, conferidas contra o que cada uma precisa. `just sops-drill-se` confere, no mesmo passo, que a identidade Secure Enclave do operador ainda decifra todo `SopsSecret`, o mesmo que `just sops-drill-dr` faz pela chave de desastre.
6. Resultado do kube-bench e do kubescape: as falhas novas desde a última revisão. O serviço `hl-kube-bench.service` declara `SuccessExitStatus=0 1`, porque o kube-bench sai com código 1 sempre que alguma checagem CIS reprova, o que não é falha da ferramenta; sem isso o systemd marcaria o serviço como falho toda vez que houvesse qualquer reprovação. Na prática, `systemctl status hl-kube-bench.service` sempre mostra sucesso, mesmo com reprovações reais, então quem for investigar precisa olhar o relatório em JSON, não o status do systemd.
7. Deriva do que vive fora do cluster: `just tofu-plan-all` roda `plan` em todo módulo de `tofu/`, e `just tofu-list` mostra a lista completa, caso um módulo novo tenha entrado desde a última revisão. Qualquer mudança que apareça foi feita à mão no console e precisa voltar ao git ou ser desfeita módulo a módulo com `just tofu <módulo> apply`. Existe também `just tofu-apply-all`, que aplica todos em sequência, mas ele não respeita a dependência entre `keycloak-master` e os outros módulos de Keycloak, então prefira o `apply` por módulo quando a deriva envolver Keycloak. No mesmo espírito, `just bootstrap --check -e chart_reconcile=true` força as roles `cilium` e `argocd` a comparar o chart com o cluster, o que o atalho por hash não faz.
8. Usuários do Keycloak: no console, os usuários de cada realm e os papéis do `master`; quem não deveria mais entrar sai dali, e o `admin` do módulo é rotacionado com `just keycloak-rotate-admin` se a data do `keycloak-master.sops.env` passou do prazo em `.config/secret-max-age.conf`.

O item 5 é, na prática, o teste de restauração deste repositório: `just sops-drill-se` e `just sops-drill-dr` não restauram um serviço inteiro, mas confirmam a única coisa que um backup de chave precisa provar, que a cópia guardada ainda decifra o que foi cifrado para ela. Um resultado `OK` sem essa checagem periódica seria uma suposição, não uma garantia, pelo mesmo motivo explicado em [testes de restauração e retenção](../aprender/retencao-testes-e-velero.md).

Enquanto o Postgres do blog continuar sem backup, como registrado em [restaurar o node](restaurar-o-node.md#3-o-postgres-nao-tem-backup-hoje), essa ausência é ela mesma um item a reconfirmar nesta revisão: um risco aceito sem revisão periódica tende a ser esquecido, não reavaliado.

## Registrar a revisão

Depois de conferir, atualize `last_review` em `.config/security-review.conf` com a data do dia e commite junto com o que a revisão tiver mudado. É essa data, comparada com `max_age_days` no mesmo arquivo, que o gate lê para decidir se a revisão venceu, então adiantá-la sem ter conferido desliga o aviso sem resolver nada. Commitar a data junto com os achados também deixa o histórico responder o que foi olhado em cada revisão, e não apenas quando ela aconteceu.

## Continue por aqui

[Checklist de segurança](../arquitetura/checklist-de-seguranca.md) é onde cada achado desta revisão vira uma linha permanente.
