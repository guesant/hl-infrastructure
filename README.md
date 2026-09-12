# hl-infrastructure

[![licença](https://img.shields.io/github/license/guesant/hl-infrastructure?style=flat-square&labelColor=0b1120&logo=gnu&logoColor=white)](LICENSE)
[![ci](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/ci.yml?branch=main&label=ci&style=flat-square&labelColor=0b1120&logo=githubactions&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/ci.yml)
[![docs](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/docs.yml?branch=main&label=docs&style=flat-square&labelColor=0b1120&logo=materialformkdocs&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/docs.yml)
[![renovate](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/renovate.yml?branch=main&label=renovate&style=flat-square&labelColor=0b1120&logo=renovate&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![renovate dependency dashboard](https://img.shields.io/badge/renovate-dependency%20dashboard-1a1f6c?style=flat-square&labelColor=0b1120&logo=renovate&logoColor=white)](https://github.com/guesant/hl-infrastructure/issues/3)

Bootstrap via Ansible e estado contínuo via GitOps para o cluster k3s do homelab.

A documentação completa está em [guesant.github.io/hl-infrastructure](https://guesant.github.io/hl-infrastructure/).

- [Visão geral](https://guesant.github.io/hl-infrastructure/): como o bootstrap e o GitOps se encaixam.
- [Tutorial](https://guesant.github.io/hl-infrastructure/tutorial/): do zero a um cluster funcionando.
- [Arquitetura](https://guesant.github.io/hl-infrastructure/arquitetura/): as roles do Ansible, os charts Helm, o padrão de GitOps, a pipeline de CI, o modelo de ameaças e a lista de variáveis.
- [Operacional](https://guesant.github.io/hl-infrastructure/operacional/): renderizar charts, rodar os quality gates, adicionar um satélite novo e o que vive fora do git.
- [Contribuindo](https://guesant.github.io/hl-infrastructure/contribuindo/): como esta documentação é organizada e escrita.

Para reportar vulnerabilidade, veja [SECURITY.md](SECURITY.md); para contribuir, [CONTRIBUTING.md](CONTRIBUTING.md).

## Agradecimentos e créditos

A estrutura e várias decisões deste repositório vieram de olhar como outras pessoas resolveram o mesmo problema:

- [Vinetos/infrastructure](https://github.com/Vinetos/infrastructure), pela organização base e ambiente do GitOps e pela validação dos manifestos em CI.
- [FerdinandWohlstein/infrastructure-live](https://github.com/FerdinandWohlstein/infrastructure-live), pelas asserts de pré-condição nas roles, pelos diagramas versionados e pelo mapa de controles com evidência.
- [Gui, o Cloud with Gui](https://x.com/cloudwithgui), pelo conteúdo sobre homelab, Kubernetes e GitOps que motivou este projeto.
- [guesant/template-documentacao-tecnica](https://github.com/guesant/template-documentacao-tecnica), pela estrutura e pelas convenções de escrita da documentação.

## Ferramentas utilizadas

Este repositório é uma composição de software livre mantido por outras pessoas. Cada linha abaixo aponta para quem o mantém.

| Ferramenta | Para que serve aqui | Licença | Autores |
| --- | --- | --- | --- |
| [k3s](https://github.com/k3s-io/k3s) | A distribuição Kubernetes que roda no node | Apache-2.0 | [contributors](https://github.com/k3s-io/k3s/graphs/contributors) |
| [Cilium](https://github.com/cilium/cilium) | CNI, substituto do kube-proxy e observabilidade de rede com Hubble | Apache-2.0 | [contributors](https://github.com/cilium/cilium/graphs/contributors) |
| [Helm](https://github.com/helm/helm) | Renderiza os charts que as roles aplicam | Apache-2.0 | [contributors](https://github.com/helm/helm/graphs/contributors) |
| [Argo CD](https://github.com/argoproj/argo-cd) | Sincroniza o cluster a partir do git | Apache-2.0 | [contributors](https://github.com/argoproj/argo-cd/graphs/contributors) |
| [Argo CD Image Updater](https://github.com/argoproj-labs/argocd-image-updater) | Promove tags novas de imagem sem commit | Apache-2.0 | [contributors](https://github.com/argoproj-labs/argocd-image-updater/graphs/contributors) |
| [cert-manager](https://github.com/cert-manager/cert-manager) | Emite e renova certificados TLS | Apache-2.0 | [contributors](https://github.com/cert-manager/cert-manager/graphs/contributors) |
| [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg) | Operador Postgres | Apache-2.0 | [contributors](https://github.com/cloudnative-pg/cloudnative-pg/graphs/contributors) |
| [plugin-barman-cloud](https://github.com/cloudnative-pg/plugin-barman-cloud) | Backup contínuo do Postgres em object storage | Apache-2.0 | [contributors](https://github.com/cloudnative-pg/plugin-barman-cloud/graphs/contributors) |
| [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) | Segredos cifrados que podem viver no git | Apache-2.0 | [contributors](https://github.com/bitnami-labs/sealed-secrets/graphs/contributors) |
| [cloudflared](https://github.com/cloudflare/cloudflared) | Túnel de saída que expõe os serviços sem abrir porta | Apache-2.0 | [contributors](https://github.com/cloudflare/cloudflared/graphs/contributors) |
| [Ansible](https://github.com/ansible/ansible) | Bootstrap do node por SSH | GPL-3.0 | [contributors](https://github.com/ansible/ansible/graphs/contributors) |
| [just](https://github.com/casey/just) | Receitas que rodam cada ferramenta em container | CC0-1.0 | [contributors](https://github.com/casey/just/graphs/contributors) |
| [Renovate](https://github.com/renovatebot/renovate) | Mantém toda versão pinada em dia | AGPL-3.0 | [contributors](https://github.com/renovatebot/renovate/graphs/contributors) |
| [MkDocs](https://github.com/mkdocs/mkdocs) e [Material for MkDocs](https://github.com/squidfunk/mkdocs-material) | Constroem o site de documentação | BSD-2-Clause e MIT | [contributors](https://github.com/mkdocs/mkdocs/graphs/contributors), [contributors](https://github.com/squidfunk/mkdocs-material/graphs/contributors) |
| [actionlint](https://github.com/rhysd/actionlint) | Lint dos workflows do GitHub Actions | MIT | [contributors](https://github.com/rhysd/actionlint/graphs/contributors) |
| [zizmor](https://github.com/zizmorcore/zizmor) | Auditoria de segurança dos workflows | MIT | [contributors](https://github.com/zizmorcore/zizmor/graphs/contributors) |
| [yamllint](https://github.com/adrienverge/yamllint) | Lint de todo YAML | GPL-3.0 | [contributors](https://github.com/adrienverge/yamllint/graphs/contributors) |
| [ansible-lint](https://github.com/ansible/ansible-lint) | Lint do playbook e das roles | GPL-3.0 | [contributors](https://github.com/ansible/ansible-lint/graphs/contributors) |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Procura segredos no histórico do git | MIT | [contributors](https://github.com/gitleaks/gitleaks/graphs/contributors) |
| [OSV-Scanner](https://github.com/google/osv-scanner) | Vulnerabilidades conhecidas em dependências | Apache-2.0 | [contributors](https://github.com/google/osv-scanner/graphs/contributors) |
| [Trivy](https://github.com/aquasecurity/trivy) | Vulnerabilidades, segredos e má configuração | Apache-2.0 | [contributors](https://github.com/aquasecurity/trivy/graphs/contributors) |
| [KubeLinter](https://github.com/stackrox/kube-linter) | Lint de segurança dos manifestos renderizados | Apache-2.0 | [contributors](https://github.com/stackrox/kube-linter/graphs/contributors) |
| [Checkov](https://github.com/bridgecrewio/checkov) | Políticas sobre os manifestos renderizados | Apache-2.0 | [contributors](https://github.com/bridgecrewio/checkov/graphs/contributors) |
| [kubeconform](https://github.com/yannh/kubeconform) | Validação de schema dos manifestos | Apache-2.0 | [contributors](https://github.com/yannh/kubeconform/graphs/contributors) |
| [ast-grep](https://github.com/ast-grep/ast-grep) | Regras estruturais próprias sobre YAML e shell | MIT | [contributors](https://github.com/ast-grep/ast-grep/graphs/contributors) |
| [jscpd](https://github.com/kucherenko/jscpd) | Relatório de duplicação de código | MIT | [contributors](https://github.com/kucherenko/jscpd/graphs/contributors) |
| [lychee](https://github.com/lycheeverse/lychee) | Verifica os links da documentação | Apache-2.0 | [contributors](https://github.com/lycheeverse/lychee/graphs/contributors) |
| [cspell](https://github.com/streetsidesoftware/cspell) | Ortografia da documentação em português e inglês | MIT | [contributors](https://github.com/streetsidesoftware/cspell/graphs/contributors) |
| [Shields.io](https://github.com/badges/shields) | As badges no topo desta página | Apache-2.0 | [contributors](https://github.com/badges/shields/graphs/contributors) |
| [Contributor Covenant](https://www.contributor-covenant.org/) | O código de conduta do projeto | CC BY 4.0 | [Coraline Ada Ehmke e colaboradores](https://github.com/EthicalSource/contributor_covenant/graphs/contributors) |

## Licença

<a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="docs/assets/gplv3.svg" alt="GPLv3" width="127"></a>

Copyright (C) 2026 Gabriel R. Antunes

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da GNU General Public License conforme publicada pela Free Software Foundation, na versão 3 da Licença ou, a seu critério, qualquer versão posterior.

Este programa é distribuído na esperança de que seja útil, mas SEM QUALQUER GARANTIA; sem sequer a garantia implícita de COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM PROPÓSITO ESPECÍFICO. Veja a GNU General Public License para mais detalhes.

Você deve ter recebido uma cópia da GNU General Public License junto com este programa, em [LICENSE](LICENSE). Se não, veja <https://www.gnu.org/licenses/>.
