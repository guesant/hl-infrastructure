# hl-infrastructure

[![licença](https://img.shields.io/github/license/guesant/hl-infrastructure?style=flat)](LICENSE)
[![ci](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/ci.yml?branch=main&label=ci&style=flat)](https://github.com/guesant/hl-infrastructure/actions/workflows/ci.yml)
[![docs](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/docs.yml?branch=main&label=docs&style=flat)](https://github.com/guesant/hl-infrastructure/actions/workflows/docs.yml)
[![renovate](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/renovate.yml?branch=main&label=renovate&style=flat)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![renovate dependency dashboard](https://img.shields.io/badge/renovate-dependency%20dashboard-1a1f6c?style=flat)](https://github.com/guesant/hl-infrastructure/issues/3)

Bootstrap via Ansible e estado contínuo via GitOps para o cluster k3s do homelab.

A documentação completa está em [guesant.github.io/hl-infrastructure](https://guesant.github.io/hl-infrastructure/).

- [Visão geral](https://guesant.github.io/hl-infrastructure/): como o bootstrap e o GitOps se encaixam.
- [Tutorial](https://guesant.github.io/hl-infrastructure/tutorial/): do zero a um cluster funcionando.
- [Arquitetura](https://guesant.github.io/hl-infrastructure/arquitetura/): as roles do Ansible, os charts Helm, o padrão de GitOps, a pipeline de CI, o modelo de ameaças e a lista de variáveis.
- [Operacional](https://guesant.github.io/hl-infrastructure/operacional/): renderizar charts, rodar os quality gates, adicionar um satélite novo e o que vive fora do git.
- [Contribuindo](https://guesant.github.io/hl-infrastructure/contribuindo/): como esta documentação é organizada e escrita.

Para reportar vulnerabilidade, veja [SECURITY.md](SECURITY.md); para contribuir, [CONTRIBUTING.md](CONTRIBUTING.md).

## Licença

<a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="docs/assets/gplv3.svg" alt="GPLv3" width="127"></a>

Copyright (C) 2026 Gabriel R. Antunes

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da GNU General Public License conforme publicada pela Free Software Foundation, na versão 3 da Licença ou, a seu critério, qualquer versão posterior.

Este programa é distribuído na esperança de que seja útil, mas SEM QUALQUER GARANTIA; sem sequer a garantia implícita de COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM PROPÓSITO ESPECÍFICO. Veja a GNU General Public License para mais detalhes.

Você deve ter recebido uma cópia da GNU General Public License junto com este programa, em [LICENSE](LICENSE). Se não, veja <https://www.gnu.org/licenses/>.
