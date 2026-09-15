# Metodologia de mudança

Toda mudança que toca o node ou o cluster segue as mesmas oito etapas, na ordem. O método existe porque o cluster tem um nó só, sem redundância que perdoe um erro, e porque quem opera é uma pessoa só, sem uma segunda que perceba um passo pulado.

1. **Pesquise antes de alterar.** Leia o changelog da versão nova, a página do componente na [arquitetura](../arquitetura/index.md) e o que o [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) diz sobre aquela fronteira. Uma mudança que contradiz a arquitetura documentada muda a documentação primeiro.

2. **Delimite o raio de explosão.** Escreva em uma frase o que para de funcionar se a mudança der errado: só o componente, o namespace de um satélite, o acesso SSH ao node, ou tudo. Mudanças em `firewall`, `ssh_hardening`, `k3s` e `cilium` estão sempre na última categoria e exigem estar na frente do console do hipervisor.

3. **Garanta o caminho de volta.** Para o Postgres, confirme que o último backup do CNPG é recente (`kubectl -n blog get cluster postgres -o jsonpath='{.status.lastSuccessfulBackup}'`). Para o node, saiba qual `git revert` desfaz a mudança e se um `just bootstrap` com o revert basta ou se o componente guarda estado fora do git ([estado fora do git](estado-fora-do-git.md)).

4. **Faça o dry-run.** `just bootstrap-check` para o Ansible; `argocd app diff` ou `kubectl diff` para manifestos do Argo; `just infra-render-charts` seguido dos gates para versão de chart. O dry-run precisa mostrar exatamente a mudança esperada e nada mais; qualquer linha inesperada volta para a etapa 1.

5. **Arme o dead man's switch.** Para toda mudança de firewall, SSH ou rede, agende antes de aplicar um retorno automático caso o acesso se perca: `sudo systemd-run --on-active=10m firewall-cmd --reload` depois de salvar a configuração antiga, ou `sudo systemd-run --on-active=10m systemctl restart ssh` com o drop-in antigo de volta. Desarme só depois de confirmar o acesso por uma sessão nova, nunca pela que já estava aberta.

6. **Aplique e observe a mudança real, não o status.** Depois de `just bootstrap` ou do sync do Argo, confirme o efeito pelo comportamento (o pod novo respondendo, a regra listada em `firewall-cmd --list-all`, o login SSH numa sessão nova), não por `changed=1` nem por `Synced`, que dizem que algo foi aplicado, não que funciona.

7. **Elimine o falso positivo.** Rode uma segunda vez: `just bootstrap` precisa terminar com `changed=0`, e `just bootstrap-check` sem nenhuma linha de diff. Se ainda há mudança, a role não é idempotente e a mudança não está terminada.

8. **Documente no mesmo commit.** A página de arquitetura ou o runbook afetado muda no mesmo commit que o código; o gate de deriva de documentação da CI falha quando a fonte de uma página muda e a página não. Nada de "atualizo a doc depois".

## Continue por aqui

O [checklist operacional](checklist.md) é a versão curta deste método para ser marcada a cada execução; [preflight e dry-run](preflight-e-dry-run.md) detalha a etapa 4.
