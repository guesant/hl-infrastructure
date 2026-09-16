# Operacional

A rotina de quem já conhece o repositório: implantar mudanças, manter o cluster e resolver tarefas específicas do dia a dia. Cada página aqui resolve uma tarefa concreta e assume familiaridade básica com Ansible, Helm e kubectl; para aprender os conceitos do zero, veja [Aprender](../aprender/index.md), e para entender por que uma peça funciona do jeito que funciona, veja a [arquitetura](../arquitetura/index.md).

- [Primeiro bootstrap](primeiro-bootstrap.md): provisiona um Raspberry Pi do zero até um cluster k3s funcionando, com Cilium, cert-manager, CloudNativePG, ArgoCD, sops-secrets-operator e o Kargo instalados.
- [Mapa do bootstrap e das credenciais](mapa-do-bootstrap-e-das-credenciais.md): as camadas, quem depende de quem, onde vive cada credencial, o que cada módulo do OpenTofu lê e o que separa bootstrap de manutenção.
- [Metodologia de mudança](metodologia-de-mudanca.md): as oito etapas de toda mudança no node ou no cluster.
- [Checklist operacional](checklist.md): o que conferir, e quando foi conferido pela última vez, a cada bootstrap ou upgrade.
- [Preflight e dry-run do bootstrap](preflight-e-dry-run.md): confere o acesso ao node e mostra o que um bootstrap mudaria, sem aplicar nada.
- [Rotacionar credenciais](rotacionar-credenciais.md): certificados e token de join do k3s, e a chave age do sops-secrets-operator, cada um num playbook próprio.
- [Renderizar os charts localmente](renderizar-charts-localmente.md): gera os manifestos Kubernetes que os sete charts Helm instalam, sem tocar em nenhum cluster real.
- [Rodar os quality gates localmente](rodar-quality-gates-localmente.md): executa o mesmo conjunto de checks que a CI roda, antes de abrir uma pull request.
- [Adicionar um satélite novo](adicionar-um-satelite.md): registra uma nova aplicação no padrão de app-of-apps do ArgoCD.
- [Estado fora do git](estado-fora-do-git.md): tudo o que o cluster precisa e não está versionado, onde vive e como se regenera.
- [Restaurar o node do zero](restaurar-o-node.md): reconstruir o cluster, confirmar a chave age e recuperar o Postgres do backup.
