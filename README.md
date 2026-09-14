# hl-infrastructure

[![licença](https://img.shields.io/github/license/guesant/hl-infrastructure?style=flat-square&labelColor=0b1120&logo=gnu&logoColor=white)](LICENSE)
[![ci](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/ci.yml?branch=main&label=ci&style=flat-square&labelColor=0b1120&logo=githubactions&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/ci.yml)
[![ci: last run](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fguesant%2Fhl-infrastructure%2Factions%2Fworkflows%2Fci.yml%2Fruns%3Fper_page%3D1&query=%24.workflow_runs%5B0%5D.updated_at&label=ci%3A%20last%20run&style=flat-square&labelColor=0b1120&logo=githubactions&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/ci.yml)
[![docs](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/docs.yml?branch=main&label=docs&style=flat-square&labelColor=0b1120&logo=materialformkdocs&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/docs.yml)
[![renovate](https://img.shields.io/github/actions/workflow/status/guesant/hl-infrastructure/renovate.yml?branch=main&label=renovate&style=flat-square&labelColor=0b1120&logo=renovate&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![renovate: last run](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fguesant%2Fhl-infrastructure%2Factions%2Fworkflows%2Frenovate.yml%2Fruns%3Fper_page%3D1&query=%24.workflow_runs%5B0%5D.updated_at&label=renovate%3A%20last%20run&style=flat-square&labelColor=0b1120&logo=renovate&logoColor=white)](https://github.com/guesant/hl-infrastructure/actions/workflows/renovate.yml)
[![renovate dependency dashboard](https://img.shields.io/badge/renovate-dependency%20dashboard-1a1f6c?style=flat-square&labelColor=0b1120&logo=renovate&logoColor=white)](https://github.com/guesant/hl-infrastructure/issues/3)
[![feito no Brasil](https://img.shields.io/badge/feito_no-Brasil-009440?style=flat-square&labelColor=0b1120)](https://pt.wikipedia.org/wiki/Brasil)

Bootstrap via Ansible e estado contínuo via GitOps para o cluster k3s do homelab.

A documentação completa está em [guesant.github.io/hl-infrastructure](https://guesant.github.io/hl-infrastructure/).

- [Visão geral](https://guesant.github.io/hl-infrastructure/): como o bootstrap e o GitOps se encaixam.
- [Aprender](https://guesant.github.io/hl-infrastructure/aprender/): o que é cada ferramenta e conceito usado aqui, independente deste repositório.
- [Arquitetura](https://guesant.github.io/hl-infrastructure/arquitetura/): as roles do Ansible, os charts Helm, o padrão de GitOps, a pipeline de CI, o modelo de ameaças e a lista de variáveis.
- [Operacional](https://guesant.github.io/hl-infrastructure/operacional/): do zero a um cluster funcionando, renderizar charts, rodar os quality gates, adicionar um satélite novo e o que vive fora do git.
- [Contribuindo](https://guesant.github.io/hl-infrastructure/contribuindo/): como esta documentação é organizada e escrita.

Para reportar vulnerabilidade, veja [SECURITY.md](SECURITY.md); para contribuir, [CONTRIBUTING.md](CONTRIBUTING.md).

## Agradecimentos e créditos

Este repositório não faz jus ao trabalho que o sustenta. Cada linha dele se apoia em código, documentação e conhecimento que outras pessoas escreveram, testaram, debateram e publicaram de graça, ao longo de décadas, em lugares diferentes, com origens, etnias, religiões, paixões e culturas diferentes, muitas vezes sem nome em lugar nenhum. A quem manteve um projeto depois do horário, respondeu uma issue de um desconhecido, escreveu o tutorial que destravou alguém, traduziu uma página, reportou um bug que nunca viu corrigido, ou só deixou o código aberto para que outros aprendessem com ele: obrigado. A lista abaixo é o que dá para nomear; o resto, invisível, é a maior parte.

### Às ideias e a quem as defendeu

Ao [movimento do software livre e de código aberto](https://www.gnu.org/philosophy/free-sw.html) e à [Free Software Foundation](https://www.fsf.org/), pela ideia de que um programa deve poder ser estudado, modificado e compartilhado, e pela GPL que este projeto adota. A quem inventou o Unix e a filosofia de ferramentas pequenas que se combinam, a quem escreveu os RFCs que fazem uma máquina qualquer falar com outra, a quem provou os teoremas por trás de cada handshake TLS e de cada chave ed25519 deste repositório, e a quem, muito antes de existir computador, insistiu que conhecimento é para ser compartilhado. A quem lutou, e ainda luta, pela liberdade de expressão, de associação e de aprender, sem a qual nada disto poderia ser publicado. Ao [NIST](https://www.nist.gov/), pelos padrões de criptografia e pelas recomendações de segurança que este repositório segue sem precisar reinventá-las, e a todas as pessoas, em CERTs, em equipes de resposta a incidentes, em programas de divulgação responsável e em projetos anônimos, que fazem da internet e do mundo um lugar melhor e mais seguro, quase sempre sem que ninguém saiba que foram elas.

### Aos padrões, à governança da rede e aos direitos digitais

À [IETF](https://www.ietf.org/), porque cada pacote deste cluster segue um RFC que alguém escreveu, discutiu em lista pública e cedeu ao mundo. Ao [W3C](https://www.w3.org/) e à [WHATWG](https://whatwg.org/), pelo HTML e pelo HTTP que servem a documentação. Ao [Unicode Consortium](https://home.unicode.org/), porque esta página está em português com acento e isso um dia foi um problema difícil. À [Mozilla](https://www.mozilla.org/), pelo Firefox, pelo MDN e por ter provado que a web aberta precisa de alguém disposto a brigar por ela. À [ISRG](https://www.abetterinternet.org/) e ao [Let's Encrypt](https://letsencrypt.org/), por terem tornado o HTTPS gratuito e automático para todo mundo. À [EFF](https://www.eff.org/), por defender em tribunal o direito de criptografar, de publicar e de consertar o que é seu. À [ICANN](https://www.icann.org/) e à [IANA](https://www.iana.org/), aos operadores dos servidores raiz, aos registros regionais como o [LACNIC](https://www.lacnic.net/) e, no Brasil, ao [NIC.br](https://www.nic.br/) e ao [CGI.br](https://cgi.br/), por manter a rede funcionando como bem comum e não como propriedade de alguém. Ao [Marco Civil da Internet](https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm) e a quem o escreveu em consulta pública, por ter colocado em lei, no Brasil, a neutralidade da rede, a privacidade e a liberdade de expressão como princípios, e não como favor. À [OWASP](https://owasp.org/), à [MITRE](https://www.cve.org/) pelo CVE, ao [OpenSSF](https://openssf.org/) e ao [OSV](https://osv.dev/), pelo trabalho coletivo de saber onde estão as falhas antes que alguém as explore. À [Apache Software Foundation](https://www.apache.org/), à [Open Source Initiative](https://opensource.org/), à [Software Freedom Conservancy](https://sfconservancy.org/), à [Creative Commons](https://creativecommons.org/) e ao [Internet Archive](https://archive.org/), por darem forma jurídica, casa e memória ao que é livre.

Aos governos e ao dinheiro público que financiaram, sem retorno imediato, a pesquisa que virou tudo isto: a ARPANET, o TCP/IP, a web nascida no [CERN](https://home.cern/), as universidades públicas onde boa parte destas ferramentas e das pessoas que as escreveram se formaram, e as agências de fomento que pagaram bolsas para quem estudava coisas que ninguém sabia para que serviriam.

### A algumas pessoas, em nome de muitas

A [Ada Lovelace](https://en.wikipedia.org/wiki/Ada_Lovelace), a [Alan Turing](https://en.wikipedia.org/wiki/Alan_Turing), a [Grace Hopper](https://en.wikipedia.org/wiki/Grace_Hopper) e a [Margaret Hamilton](https://en.wikipedia.org/wiki/Margaret_Hamilton_(software_engineer)), por terem imaginado o software antes de ele existir e por tê-lo levado à Lua. A [Ken Thompson](https://en.wikipedia.org/wiki/Ken_Thompson), [Dennis Ritchie](https://en.wikipedia.org/wiki/Dennis_Ritchie) e [Brian Kernighan](https://en.wikipedia.org/wiki/Brian_Kernighan), pelo Unix e pelo C. A [Vint Cerf](https://en.wikipedia.org/wiki/Vint_Cerf), [Bob Kahn](https://en.wikipedia.org/wiki/Bob_Kahn), [Radia Perlman](https://en.wikipedia.org/wiki/Radia_Perlman) e [Jon Postel](https://en.wikipedia.org/wiki/Jon_Postel), pela rede. A [Tim Berners-Lee](https://en.wikipedia.org/wiki/Tim_Berners-Lee), pela web, e por tê-la dado de graça. A [Whitfield Diffie](https://en.wikipedia.org/wiki/Whitfield_Diffie), [Martin Hellman](https://en.wikipedia.org/wiki/Martin_Hellman), [Ralph Merkle](https://en.wikipedia.org/wiki/Ralph_Merkle), [Ron Rivest](https://en.wikipedia.org/wiki/Ron_Rivest), [Adi Shamir](https://en.wikipedia.org/wiki/Adi_Shamir), [Leonard Adleman](https://en.wikipedia.org/wiki/Leonard_Adleman) e [Daniel J. Bernstein](https://en.wikipedia.org/wiki/Daniel_J._Bernstein), pela criptografia que protege cada conexão daqui, e a [Phil Zimmermann](https://en.wikipedia.org/wiki/Phil_Zimmermann), por ter insistido que ela é para todo mundo. A [Richard Stallman](https://en.wikipedia.org/wiki/Richard_Stallman), pelo GNU e pela GPL, e a [Linus Torvalds](https://en.wikipedia.org/wiki/Linus_Torvalds), pelo Linux e pelo git. A [Ian Murdock](https://en.wikipedia.org/wiki/Ian_Murdock), pelo Debian. A [Guido van Rossum](https://en.wikipedia.org/wiki/Guido_van_Rossum), pelo Python, e a [Rob Pike](https://en.wikipedia.org/wiki/Rob_Pike) e [Ken Thompson](https://en.wikipedia.org/wiki/Ken_Thompson), de novo, pelo Go. A [Aaron Swartz](https://en.wikipedia.org/wiki/Aaron_Swartz), por acreditar que o conhecimento deve ser livre e por ter pagado caro por isso. E a cada pessoa cujo nome não cabe aqui, porque a história do software é feita sobretudo de quem ninguém lembra.

### A quem mantém o que este projeto usa

Ao [Linux](https://kernel.org/) e a quem o mantém, pelo kernel em que tudo isto roda. Ao [Projeto GNU](https://www.gnu.org/), pelo coreutils, pelo bash e pelo grep que estão em todo script daqui. Ao [Debian](https://www.debian.org/), pela base que o Raspberry Pi OS herda e pela paciência de empacotar o mundo. À [OpenSSL](https://www.openssl.org/) e ao [OpenSSH](https://www.openssh.com/), pela criptografia e pelo acesso que protegem o node em silêncio. Ao [Renovate](https://docs.renovatebot.com/), por fazer sozinho, todo dia, a parte mais tediosa de manter um repositório vivo. E a cada mantenedor das ferramentas listadas nas tabelas abaixo, muitos dos quais cuidam de algo que milhões usam sem nunca saber o nome de quem cuida.

### Às organizações que sustentam essas comunidades

À [SUSE](https://www.suse.com/) e à comunidade [openSUSE](https://www.opensuse.org/), que mantêm o k3s e o Rancher e décadas de Linux. À [Red Hat](https://www.redhat.com/), pelo Ansible, pelo systemd, pelo firewalld, pelo Quay e por boa parte do que faz um servidor Linux funcionar. À [Microsoft](https://www.microsoft.com/), pelo GitHub que hospeda este repositório e roda sua CI, pelo npm e pelo VS Code em que ele foi escrito. Ao [Google](https://opensource.google/), pelo Kubernetes que deu origem a tudo isto, pelo Go em que a maior parte destas ferramentas é escrita e pelo OSV. À [Canonical](https://canonical.com/), pelo Ubuntu em que os runners da CI rodam. À [Cloudflare](https://www.cloudflare.com/), pelo DNS e pelo túnel. À [Isovalent](https://isovalent.com/) e à Cisco, pelo Cilium e pelo eBPF em produção. À [Intuit](https://opensource.intuit.com/) e à comunidade Argo, pelo Argo CD. À [EnterpriseDB](https://www.enterprisedb.com/), pelo CloudNativePG, e ao PostgreSQL Global Development Group, por trinta anos de banco de dados livre. À [Aqua Security](https://www.aquasec.com/), pelo Trivy; à [Prisma Cloud](https://www.paloaltonetworks.com/prisma/cloud), pelo Checkov; ao [StackRox](https://www.stackrox.io/), pelo KubeLinter; à [Mend](https://www.mend.io/), pelo Renovate; à [Venafi](https://venafi.com/), pelo cert-manager; à comunidade [getsops](https://github.com/getsops/sops), por manter o SOPS depois que a Mozilla o originou; a [Filippo Valsorda](https://filippo.io/), pelo age; à [Docker](https://www.docker.com/), pelos contêineres; à [Raspberry Pi Foundation](https://www.raspberrypi.org/), por colocar um computador capaz de rodar Kubernetes no preço de um jantar; à [Linux Foundation](https://www.linuxfoundation.org/) e à [CNCF](https://www.cncf.io/), por dar casa neutra a metade dos projetos desta página; à [Wikimedia Foundation](https://wikimediafoundation.org/), pelo conhecimento livre e por hospedar o logo da GPL; à [Python Software Foundation](https://www.python.org/psf/) e à [Rust Foundation](https://foundation.rust-lang.org/), pelas linguagens em que os linters daqui são escritos.

### Pela infraestrutura e hospedagem

Ao [GitHub](https://github.com/), que guarda o repositório, roda a CI, publica a documentação nas Pages e as imagens no GHCR; ao [Docker Hub](https://hub.docker.com/), ao [Quay](https://quay.io/) e ao GHCR, que distribuem as imagens; ao [PyPI](https://pypi.org/) e ao [npm](https://www.npmjs.com/), que distribuem as ferramentas; ao [Shields.io](https://shields.io/), pelas badges; ao [Wikimedia Commons](https://commons.wikimedia.org/), por hospedar o logo da GPL; e ao [CRDs-catalog da Datree](https://github.com/datreeio/CRDs-catalog), pelos schemas que validam os manifestos na CI.

### Aos invisíveis

A quem desenhou os chips e a quem trabalhou nas fábricas onde eles foram gravados; a quem tirou da terra o silício, o cobre, o estanho e o lítio; a quem montou a placa, embalou, carregou o caminhão, pilotou o navio e entregou a caixa. A quem puxou o cabo de fibra pela rua, pelo poste e pelo fundo do oceano, e a quem sobe na torre quando o link cai. A quem gera e distribui a energia que mantém o node ligado, de madrugada, no frio, na chuva. A quem constrói e limpa e vigia os datacenters onde a CI roda e o repositório vive. A quem planta, colhe e cozinha o que alimenta todas essas pessoas. A quem cuida da cidade enquanto ela dorme: garis, padeiros, motoristas, mecânicos, eletricistas, encanadores, pedreiros, porteiros, cuidadores, veterinários, voluntários que aparecem quando ninguém é pago para aparecer. A quem cuida da saúde de todas elas: médicas, enfermeiros, agentes de saúde, cuidadores. A quem garante a segurança e apaga incêndios. A quem ensina: professoras, bibliotecários, quem escreveu o livro, quem gravou o vídeo, quem respondeu a pergunta no fórum às três da manhã. A quem traduz, para que o conhecimento cruze fronteiras. A quem legisla e defende o direito de publicar, criptografar e aprender.

Aos matemáticos, que fizeram o trabalho abstrato séculos antes de alguém precisar dele num handshake. Aos cientistas e engenheiros, que transformaram esse trabalho em transistor, em fibra, em protocolo, em algo que liga. Aos artistas, que desenharam os ícones, escolheram as fontes, compuseram o que tocava enquanto isto era escrito e lembraram que uma ferramenta também pode ser bonita. A quem não gosta de software e nem quer gostar, e ainda assim sustenta, com o próprio trabalho, o mundo em que software faz sentido. A quem se formou e a quem não se formou e contribuiu muito mais do que quem tem o papel: o conhecimento que este repositório usa não pediu diploma a ninguém. Aos psicólogos e a quem cuida da saúde mental, porque manter um sistema é também manter quem o mantém, e ninguém escreve código bom a partir do esgotamento.

A quem sobe num palco em qualquer cidade do mundo para contar o que aprendeu, nas conferências grandes e nos meetups de dez pessoas numa sala emprestada; a quem organiza esses encontros de graça, arruma as cadeiras e paga o café. A quem grava vídeo, escreve blog, mantém newsletter, responde no fórum e no chat, traduz legenda, publica o slide depois da palestra. Boa parte do que este repositório faz foi aprendida assim, de alguém que não precisava ensinar e ensinou.

A quem não desistiu, apesar de tudo. E, com o mesmo respeito, a quem desistiu: quem saiu da área, ou nunca conseguiu entrar, porque lhe negaram dignidade por causa de orientação sexual, religião, etnia, nacionalidade ou sexo; quem foi tratado como se não pertencesse; quem carregou traumas que ninguém viu e não teve com quem dividir. O que essas pessoas teriam construído não existe, e a área é mais pobre por isso. Que este repositório, na sua pequenez, seja um lugar onde isso não se repete.

E, antes de todos, a quem lutou com o próprio sangue pela liberdade, pela dignidade, pelo respeito, pela igualdade, pela fraternidade e pela justiça: quem enfrentou ditaduras, escravidão, colonização e perseguição, quem organizou greves e marchas, quem foi preso, torturado ou morto por dizer o que não podia ser dito. Um repositório público, escrito por quem quis, sobre o que quis, publicado para quem quiser ler, só existe porque essas pessoas pagaram por isso antes. Nenhum agradecimento é suficiente; o mínimo é não esquecer.

À família, pelo tempo que este projeto tomou e pela paciência com cada "só mais um commit". Aos amigos que ouviram falar de Kubernetes sem pedir. Aos animais que ficaram deitados ao lado da mesa enquanto isto era escrito, sem entender nada e sem precisar entender.

Nada aqui foi feito sozinho. Se este repositório for útil a alguém, o mérito é distribuído entre todas essas pessoas, quase todas anônimas para quem lê esta página, e o que resta de erro é só de quem o mantém.

### Às bibliotecas

Às bibliotecas, físicas e digitais, e a quem cataloga, conserva e digitaliza o que outros descartariam. Nenhum protocolo, nenhuma ferramenta e nenhuma decisão de arquitetura deste repositório existiria fora de um contexto histórico maior, e é bom não esquecer isso. Entre tantas, à Biblioteca Nacional do Brasil, pela [Biblioteca Nacional Digital](https://bndigital.bn.gov.br/), pelo [acervo digital](https://bndigital.bn.gov.br/acervodigital/) e pela [hemeroteca digital](https://memoria.bn.gov.br/hdb/periodico.aspx), por preservarem a história de forma aberta a quem quiser consultar.

### Inspirações diretas

A estrutura e várias decisões deste repositório vieram de olhar como outras pessoas resolveram o mesmo problema:

- [Vinetos/infrastructure](https://github.com/Vinetos/infrastructure), pela organização base e ambiente do GitOps e pela validação dos manifestos em CI.
- [FerdinandWohlstein/infrastructure-live](https://github.com/FerdinandWohlstein/infrastructure-live), pelas asserts de pré-condição nas roles, pelos diagramas versionados e pelo mapa de controles com evidência.
- [Gui, o Cloud with Gui](https://github.com/gossilva) ([@cloudwithgui](https://x.com/cloudwithgui)), pela inspiração, pelo conteúdo sobre homelab, Kubernetes e GitOps que ele compartilha de graça e que motivou este projeto, e por ser quem ele é.
- [Luiz Rosa](https://github.com/Felipalds) ([@felipalds](https://x.com/felipalds), [luizrosa.me](https://www.luizrosa.me)), pela inspiração, por tudo o que compartilha sobre Linux, Go e infraestrutura, e por ser quem ele é.
- [guesant/template-documentacao-tecnica](https://github.com/guesant/template-documentacao-tecnica), pela estrutura e pelas convenções de escrita da documentação.
- Ao Prof. Danilo Escudeiro e ao [Ladesa](https://github.com/ladesa-ro/infrastructure), o Laboratório de Desenvolvimento de Softwares Acadêmicos, pelo espaço cedido para aprender e aplicar DevOps, infraestrutura, Kubernetes e Docker num ambiente real; muito do que está aqui foi ensaiado lá primeiro.

## Ferramentas utilizadas

Este repositório é uma composição de software livre mantido por outras pessoas, rodando sobre hardware e sistema que também não são deste projeto. Cada linha aponta para quem mantém a peça e para o texto da licença sob a qual ela é distribuída.

### Hardware e sistema operacional

| Projeto | Para que serve aqui | Licença | Autores |
| --- | --- | --- | --- |
| [Raspberry Pi](https://www.raspberrypi.com/) | O hardware do node | hardware, [documentação CC BY-SA 4.0](https://github.com/raspberrypi/documentation/blob/master/LICENSE.md) | [Raspberry Pi Ltd](https://www.raspberrypi.com/about/) |
| [Raspberry Pi OS](https://www.raspberrypi.com/software/operating-systems/) | O sistema operacional do node, derivado do Debian | [várias, conforme o Debian](https://www.debian.org/legal/licenses/) | [Raspberry Pi Ltd](https://github.com/RPi-Distro) |
| [Debian](https://www.debian.org/) | A base do sistema, o apt e os pacotes de hardening | [DFSG, várias licenças livres](https://www.debian.org/legal/licenses/) | [Debian Project](https://www.debian.org/devel/people) |
| [Linux](https://kernel.org/) | O kernel, com os cgroups e o eBPF de que o k3s e o Cilium dependem | [GPL-2.0 com exceção de syscall](https://github.com/torvalds/linux/blob/master/COPYING) | [contributors](https://github.com/torvalds/linux/graphs/contributors) |
| [GNU coreutils](https://www.gnu.org/software/coreutils/) | Os utilitários básicos de que todo script e toda role dependem | [GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.html) | [GNU Project](https://www.gnu.org/software/coreutils/coreutils.html) |
| [GNU Bash](https://www.gnu.org/software/bash/) | O shell dos scripts em `.tools/` e das tasks `shell` do Ansible | [GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.html) | [GNU Project](https://www.gnu.org/software/bash/) |
| [GNU grep](https://www.gnu.org/software/grep/) | Os gates de prosa, imagem pinada e versão dependem dele | [GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.html) | [GNU Project](https://www.gnu.org/software/grep/) |
| [systemd](https://systemd.io/) | Init, journal e os timers de manutenção | [LGPL-2.1-or-later e GPL-2.0-or-later](https://github.com/systemd/systemd/blob/main/LICENSES/README.md) | [contributors](https://github.com/systemd/systemd/graphs/contributors) |
| [OpenSSH](https://www.openssh.com/) | O único acesso administrativo ao node | [BSD](https://github.com/openssh/openssh-portable/blob/master/LICENCE) | [OpenBSD Project](https://github.com/openssh/openssh-portable/graphs/contributors) |
| [firewalld](https://firewalld.org/) | O firewall do node | [GPL-2.0-or-later](https://github.com/firewalld/firewalld/blob/main/COPYING) | [contributors](https://github.com/firewalld/firewalld/graphs/contributors) |
| [fail2ban](https://github.com/fail2ban/fail2ban) | Bane origens com tentativas repetidas de login SSH | [GPL-2.0-or-later](https://github.com/fail2ban/fail2ban/blob/master/COPYING) | [contributors](https://github.com/fail2ban/fail2ban/graphs/contributors) |
| [audit](https://github.com/linux-audit/audit-userspace) | Auditoria de chamadas de sistema | [GPL-2.0-or-later](https://github.com/linux-audit/audit-userspace/blob/master/COPYING) | [contributors](https://github.com/linux-audit/audit-userspace/graphs/contributors) |
| [unattended-upgrades](https://github.com/mvo5/unattended-upgrades) | Correções de segurança automáticas | [GPL-2.0-or-later](https://github.com/mvo5/unattended-upgrades/blob/master/COPYING) | [contributors](https://github.com/mvo5/unattended-upgrades/graphs/contributors) |

### Plataforma

| Projeto | Para que serve aqui | Licença | Autores |
| --- | --- | --- | --- |
| [Kubernetes](https://kubernetes.io/) | A API que tudo abaixo implementa ou consome | [Apache-2.0](https://github.com/kubernetes/kubernetes/blob/master/LICENSE) | [contributors](https://github.com/kubernetes/kubernetes/graphs/contributors) |
| [k3s](https://k3s.io/) | A distribuição Kubernetes que roda no node | [Apache-2.0](https://github.com/k3s-io/k3s/blob/master/LICENSE) | [contributors](https://github.com/k3s-io/k3s/graphs/contributors) |
| [containerd](https://containerd.io/) | O runtime de contêineres embutido no k3s | [Apache-2.0](https://github.com/containerd/containerd/blob/main/LICENSE) | [contributors](https://github.com/containerd/containerd/graphs/contributors) |
| [Cilium](https://cilium.io/) | CNI, substituto do kube-proxy e observabilidade de rede com Hubble | [Apache-2.0](https://github.com/cilium/cilium/blob/main/LICENSE) | [contributors](https://github.com/cilium/cilium/graphs/contributors) |
| [Helm](https://helm.sh/) | Renderiza os charts que as roles aplicam | [Apache-2.0](https://github.com/helm/helm/blob/main/LICENSE) | [contributors](https://github.com/helm/helm/graphs/contributors) |
| [Argo CD](https://argo-cd.readthedocs.io/) | Sincroniza o cluster a partir do git | [Apache-2.0](https://github.com/argoproj/argo-cd/blob/master/LICENSE) | [contributors](https://github.com/argoproj/argo-cd/graphs/contributors) |
| [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/) | Promove tags novas de imagem sem commit | [Apache-2.0](https://github.com/argoproj-labs/argocd-image-updater/blob/master/LICENSE) | [contributors](https://github.com/argoproj-labs/argocd-image-updater/graphs/contributors) |
| [cert-manager](https://cert-manager.io/) | Emite e renova certificados TLS | [Apache-2.0](https://github.com/cert-manager/cert-manager/blob/master/LICENSE) | [contributors](https://github.com/cert-manager/cert-manager/graphs/contributors) |
| [PostgreSQL](https://www.postgresql.org/) | O banco de dados dos satélites | [PostgreSQL License](https://www.postgresql.org/about/licence/) | [PostgreSQL Global Development Group](https://www.postgresql.org/community/contributors/) |
| [CloudNativePG](https://cloudnative-pg.io/) | Operador Postgres | [Apache-2.0](https://github.com/cloudnative-pg/cloudnative-pg/blob/main/LICENSE) | [contributors](https://github.com/cloudnative-pg/cloudnative-pg/graphs/contributors) |
| [sops-secrets-operator](https://github.com/isindir/sops-secrets-operator) | Decifra `SopsSecret` cifrados com SOPS/age direto no cluster | [MPL-2.0](https://github.com/isindir/sops-secrets-operator/blob/master/LICENSE) | [contributors](https://github.com/isindir/sops-secrets-operator/graphs/contributors) |
| [SOPS](https://github.com/getsops/sops) | Cifra os `SopsSecret` localmente antes do commit | [MPL-2.0](https://github.com/getsops/sops/blob/main/LICENSE) | [contributors](https://github.com/getsops/sops/graphs/contributors) |
| [age](https://github.com/FiloSottile/age) | O par de chaves que o SOPS usa pra cifrar e decifrar | [BSD-3-Clause](https://github.com/FiloSottile/age/blob/main/LICENSE) | [contributors](https://github.com/FiloSottile/age/graphs/contributors) |
| [cloudflared](https://github.com/cloudflare/cloudflared) | Túnel de saída que expõe os serviços sem abrir porta | [Apache-2.0](https://github.com/cloudflare/cloudflared/blob/master/LICENSE) | [contributors](https://github.com/cloudflare/cloudflared/graphs/contributors) |
| [OpenTofu](https://opentofu.org/) | Declara o túnel e o DNS do blog na Cloudflare, com state cifrado | [MPL-2.0](https://github.com/opentofu/opentofu/blob/main/LICENSE) | [contributors](https://github.com/opentofu/opentofu/graphs/contributors) |
| [Cloudflare Terraform provider](https://github.com/cloudflare/terraform-provider-cloudflare) | A ponte entre o OpenTofu e a API da Cloudflare | [Apache-2.0](https://github.com/cloudflare/terraform-provider-cloudflare/blob/main/LICENSE) | [contributors](https://github.com/cloudflare/terraform-provider-cloudflare/graphs/contributors) |
| [OpenSSL](https://www.openssl.org/) | Gera o token de join na rotação de credenciais | [Apache-2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt) | [contributors](https://github.com/openssl/openssl/graphs/contributors) |

### Automação e documentação

| Projeto | Para que serve aqui | Licença | Autores |
| --- | --- | --- | --- |
| [Ansible](https://www.ansible.com/) | Bootstrap do node por SSH | [GPL-3.0-or-later](https://github.com/ansible/ansible/blob/devel/COPYING) | [contributors](https://github.com/ansible/ansible/graphs/contributors) |
| [Python](https://www.python.org/) | Roda o Ansible, o MkDocs e dois dos linters | [PSF-2.0](https://docs.python.org/3/license.html) | [Python Software Foundation](https://github.com/python/cpython/graphs/contributors) |
| [just](https://just.systems/) | Receitas que rodam cada ferramenta em container | [CC0-1.0](https://github.com/casey/just/blob/master/LICENSE) | [contributors](https://github.com/casey/just/graphs/contributors) |
| [Docker](https://www.docker.com/) | Isola cada ferramenta numa imagem, local e na CI | [Apache-2.0](https://github.com/docker/cli/blob/master/LICENSE) | [contributors](https://github.com/docker/cli/graphs/contributors) |
| [git](https://git-scm.com/) | O histórico que o Argo sincroniza e o gitleaks varre | [GPL-2.0](https://github.com/git/git/blob/master/COPYING) | [contributors](https://github.com/git/git/graphs/contributors) |
| [curl](https://curl.se/) | Baixa os instaladores nas roles | [curl](https://curl.se/docs/copyright.html) | [contributors](https://github.com/curl/curl/graphs/contributors) |
| [jq](https://jqlang.org/) | Filtra JSON no script de manutenção e no resumo da CI | [MIT](https://github.com/jqlang/jq/blob/master/COPYING) | [contributors](https://github.com/jqlang/jq/graphs/contributors) |
| [Renovate](https://docs.renovatebot.com/) | Mantém toda versão pinada em dia | [AGPL-3.0](https://github.com/renovatebot/renovate/blob/main/license) | [contributors](https://github.com/renovatebot/renovate/graphs/contributors) |
| [MkDocs](https://www.mkdocs.org/) e [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) | Constroem o site de documentação | [BSD-2-Clause](https://github.com/mkdocs/mkdocs/blob/master/LICENSE) e [MIT](https://github.com/squidfunk/mkdocs-material/blob/master/LICENSE) | [contributors](https://github.com/mkdocs/mkdocs/graphs/contributors), [contributors](https://github.com/squidfunk/mkdocs-material/graphs/contributors) |
| [Mermaid](https://mermaid.js.org/) | Os diagramas da documentação | [MIT](https://github.com/mermaid-js/mermaid/blob/develop/LICENSE) | [contributors](https://github.com/mermaid-js/mermaid/graphs/contributors) |
| [Shields.io](https://shields.io/) e [Simple Icons](https://simpleicons.org/) | As badges no topo desta página e seus ícones | [Apache-2.0](https://github.com/badges/shields/blob/master/LICENSE-APACHE) e [CC0-1.0](https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md) | [contributors](https://github.com/badges/shields/graphs/contributors), [contributors](https://github.com/simple-icons/simple-icons/graphs/contributors) |
| [Contributor Covenant](https://www.contributor-covenant.org/) | O código de conduta do projeto | [CC BY 4.0](https://github.com/EthicalSource/contributor_covenant/blob/release/LICENSE.md) | [Coraline Ada Ehmke e colaboradores](https://github.com/EthicalSource/contributor_covenant/graphs/contributors) |
| [GitHub](https://github.com/) | Hospeda o repositório, roda a CI, publica a documentação e as imagens | serviço | [GitHub](https://github.com/about) |
| [Cloudflare](https://www.cloudflare.com/) | DNS e o túnel que expõe os serviços | serviço | [Cloudflare](https://www.cloudflare.com/about-overview/) |

### Quality gates

| Projeto | Para que serve aqui | Licença | Autores |
| --- | --- | --- | --- |
| [actionlint](https://rhysd.github.io/actionlint/) | Lint dos workflows do GitHub Actions | [MIT](https://github.com/rhysd/actionlint/blob/main/LICENSE.txt) | [contributors](https://github.com/rhysd/actionlint/graphs/contributors) |
| [zizmor](https://docs.zizmor.sh/) | Auditoria de segurança dos workflows | [MIT](https://github.com/zizmorcore/zizmor/blob/main/LICENSE) | [contributors](https://github.com/zizmorcore/zizmor/graphs/contributors) |
| [yamllint](https://yamllint.readthedocs.io/) | Lint de todo YAML | [GPL-3.0](https://github.com/adrienverge/yamllint/blob/master/LICENSE) | [contributors](https://github.com/adrienverge/yamllint/graphs/contributors) |
| [ansible-lint](https://ansible.readthedocs.io/projects/lint/) | Lint do playbook e das roles | [GPL-3.0](https://github.com/ansible/ansible-lint/blob/main/COPYING) | [contributors](https://github.com/ansible/ansible-lint/graphs/contributors) |
| [ShellCheck](https://www.shellcheck.net/) | Lint dos scripts de shell em `.tools/` | [GPL-3.0](https://github.com/koalaman/shellcheck/blob/master/LICENSE) | [contributors](https://github.com/koalaman/shellcheck/graphs/contributors) |
| [Hadolint](https://github.com/hadolint/hadolint) | Lint do Dockerfile das ferramentas de CI | [GPL-3.0](https://github.com/hadolint/hadolint/blob/master/LICENSE) | [contributors](https://github.com/hadolint/hadolint/graphs/contributors) |
| [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) | Lint da estrutura de todo Markdown | [MIT](https://github.com/DavidAnson/markdownlint-cli2/blob/main/LICENSE) | [contributors](https://github.com/DavidAnson/markdownlint-cli2/graphs/contributors) |
| [gitleaks](https://gitleaks.io/) | Procura segredos no histórico do git | [MIT](https://github.com/gitleaks/gitleaks/blob/master/LICENSE) | [contributors](https://github.com/gitleaks/gitleaks/graphs/contributors) |
| [OSV-Scanner](https://google.github.io/osv-scanner/) | Vulnerabilidades conhecidas em dependências | [Apache-2.0](https://github.com/google/osv-scanner/blob/main/LICENSE) | [contributors](https://github.com/google/osv-scanner/graphs/contributors) |
| [Trivy](https://trivy.dev/) | Vulnerabilidades, segredos e má configuração | [Apache-2.0](https://github.com/aquasecurity/trivy/blob/main/LICENSE) | [contributors](https://github.com/aquasecurity/trivy/graphs/contributors) |
| [KubeLinter](https://docs.kubelinter.io/) | Lint de segurança dos manifestos renderizados | [Apache-2.0](https://github.com/stackrox/kube-linter/blob/main/LICENSE) | [contributors](https://github.com/stackrox/kube-linter/graphs/contributors) |
| [Checkov](https://www.checkov.io/) | Políticas sobre os manifestos renderizados | [Apache-2.0](https://github.com/bridgecrewio/checkov/blob/main/LICENSE) | [contributors](https://github.com/bridgecrewio/checkov/graphs/contributors) |
| [kubeconform](https://github.com/yannh/kubeconform) | Validação de schema dos manifestos | [Apache-2.0](https://github.com/yannh/kubeconform/blob/master/LICENSE) | [contributors](https://github.com/yannh/kubeconform/graphs/contributors) |
| [ast-grep](https://ast-grep.github.io/) | Regras estruturais próprias sobre YAML e shell | [MIT](https://github.com/ast-grep/ast-grep/blob/main/LICENSE) | [contributors](https://github.com/ast-grep/ast-grep/graphs/contributors) |
| [jscpd](https://github.com/kucherenko/jscpd) | Relatório de duplicação de código | [MIT](https://github.com/kucherenko/jscpd/blob/master/LICENSE) | [contributors](https://github.com/kucherenko/jscpd/graphs/contributors) |
| [lychee](https://lychee.cli.rs/) | Verifica os links da documentação | [Apache-2.0 ou MIT](https://github.com/lycheeverse/lychee/blob/master/LICENSE-APACHE) | [contributors](https://github.com/lycheeverse/lychee/graphs/contributors) |
| [cspell](https://cspell.org/) | Ortografia da documentação em português e inglês | [MIT](https://github.com/streetsidesoftware/cspell/blob/main/LICENSE) | [contributors](https://github.com/streetsidesoftware/cspell/graphs/contributors) |

## Licença

<a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="docs/assets/gplv3.svg" alt="GPLv3" width="127"></a>

Copyright (C) 2026 Gabriel R. Antunes

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da GNU General Public License conforme publicada pela Free Software Foundation, na versão 3 da Licença ou, a seu critério, qualquer versão posterior.

Este programa é distribuído na esperança de que seja útil, mas SEM QUALQUER GARANTIA; sem sequer a garantia implícita de COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM PROPÓSITO ESPECÍFICO. Veja a GNU General Public License para mais detalhes.

Você deve ter recebido uma cópia da GNU General Public License junto com este programa, em [LICENSE](LICENSE). Se não, veja <https://www.gnu.org/licenses/>.
