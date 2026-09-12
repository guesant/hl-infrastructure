# Operacional

A rotina de quem já conhece o repositório: implantar mudanças, manter o cluster e resolver tarefas específicas do dia a dia. Cada página aqui resolve uma tarefa concreta e assume familiaridade básica com Ansible, Helm e kubectl; para aprender os conceitos do zero, veja o [tutorial](../tutorial/index.md), e para entender por que uma peça funciona do jeito que funciona, veja a [arquitetura](../arquitetura/index.md).

- [Renderizar os charts localmente](renderizar-charts-localmente.md): gera os manifestos Kubernetes que os sete charts Helm instalam, sem tocar em nenhum cluster real.
- [Rodar os quality gates localmente](rodar-quality-gates-localmente.md): executa o mesmo conjunto de checks que a CI roda, antes de abrir uma pull request.
- [Adicionar um satélite novo](adicionar-um-satelite.md): registra uma nova aplicação no padrão de app-of-apps do ArgoCD.
