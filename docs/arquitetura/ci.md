# A pipeline de CI

<!-- source-of-trust paths="justfile .config/kube-linter.yaml" -->

O `ci` roda em todo push em `main` e em todo pull request, com todos os jobs em paralelo.

Um último job, `gate`, depende de todos os outros via `needs:`, escreve uma tabela com o resultado de cada um no resumo do run e falha se qualquer um deles falhar ou for cancelado.

É esse único job, e não a lista inteira, que faz sentido marcar como check obrigatório na branch protection.

Num pull request nem todo job roda. Um job inicial, `changes`, usa o `paths-filter` para dizer que áreas o PR toca.

As áreas que ele reconhece são `ansible/charts/tofu/docs/tools`.

Os jobs caros ou específicos declaram `needs: changes` com um `if:` sobre essas saídas.

A tabela abaixo resume quando cada família de job roda.

| Job(s) | Roda quando muda |
| --- | --- |
| `helm-lint`, `kube-linter`, `checkov`, `kubeconform`, `trivy-config`, `kubescape`, `trivy-images`, `pod-security`, `sopssecrets` | `argocd/`, `ansible/`, `.tools/`, `.config/`, `.trivyignore.yaml` ou `justfile` |
| `ansible-lint` | `ansible/` |
| `tofu` | `tofu/` ou os scripts e políticas dele |
| `markdownlint`, `spelling` | doc ou Markdown |
| `hadolint`, `shellcheck` | `.tools/` |

Os jobs que olham o repositório inteiro, como `gitleaks/osv-scanner/trivy-fs/prose/placeholders/docs-consistency/ast-grep/jscpd/commitlint`, rodam sempre.

Em push para main, no agendamento diário e no disparo manual, a saída `all` do `changes` é verdadeira e tudo roda; o filtro existe só para encurtar o ciclo de um PR, nunca para deixar main passar sem a bateria inteira.

Um job pulado aparece como `skipped` na tabela do `gate`, que o aceita como sucesso.

`failure` e `cancelled` continuam derrubando o gate.

A concorrência é por ref: um push novo no mesmo PR cancela o run anterior, enquanto runs de `main` nunca são cancelados.

A distinção entre os dois estados é o que permite o filtro de caminhos existir sem afrouxar o gate: pular é uma decisão declarada num `if:`, e ser cancelado é uma interrupção, que nunca conta como verificação feita.

Alguns jobs guardam estado entre runs com o cache do GitHub Actions, além das camadas das imagens de ferramenta, resumidos na tabela abaixo.

| Cache | Chave por |
| --- | --- |
| Coleções do Galaxy (`ansible-lint`) | `ansible/requirements.yml` |
| Banco de vulnerabilidades do trivy (`trivy-fs`, `trivy-config`) | run, com restauração do mais recente |
| Schemas do `kubeconform` | versões dos charts |
| Espelho de providers do OpenTofu (`.cache/tofu/mirror`) | `versions.tf` e o script que espelha |

O banco de vulnerabilidades muda todo dia e o trivy o atualiza sozinho quando está velho. Nada disso muda o que é verificado; só evita baixar de novo o que não mudou. Os diretórios de cache ficam no `.gitignore`.

## Os demais workflows

Cobertura de segurança, qualidade estrutural e lint de infraestrutura vivem no [ci.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/ci.yml); os workflows que ficam fora dele cuidam da manutenção deste repositório.

Nenhum deles entra no `gate`, porque nenhum verifica a mudança em revisão: eles publicam a nota de práticas do repositório, abrem pull requests de atualização, constroem este site e rotacionam credenciais sob disparo manual.

A consequência é que uma falha em qualquer um deles não bloqueia um merge, e aparece só como workflow vermelho na aba de Actions.

O [scorecard.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/scorecard.yml) roda o OpenSSF Scorecard a cada push em `main`, toda segunda-feira e a cada mudança de proteção de branch.

Ele avalia práticas do repositório, como proteção de branch, actions pinadas por SHA e permissões mínimas dos workflows, publica a nota que o selo do README mostra e envia os achados para o code scanning do GitHub.

Só esse job ganha `security-events: write` e `id-token: write`, este último para o Scorecard provar ao serviço de publicação que o resultado veio deste repositório.

O [renovate.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/renovate.yml) roda self-hosted todo dia de manhã, isolado num environment restrito à branch principal, e bumpa a versão de cada chart Helm diretamente em `ansible/group_vars/all/versions.yml`, o arquivo real que o Ansible lê.

Num push em `main` ele só roda quando o push muda a própria configuração (`.github/renovate.json` ou o workflow), para validar a mudança sem esperar o dia seguinte.

Rodar a cada push custava um tempo real por commit, e o ganho era atualizar na hora uma PR do Renovate que conflitasse com um push admin em `main`; com um operador só, esse conflito pode esperar a janela agendada da manhã seguinte, ou um disparo manual.

O [docs.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/docs.yml) constrói este site com MkDocs e publica no GitHub Pages quando o push é em main, mas só quando o push toca o que o build lê: `docs/`, `.config/mkdocs.yml` ou o próprio workflow.

Os links das páginas para o código são URLs absolutas do GitHub, então mudar um script ou um manifesto não muda o site; em pull requests, ele só constrói com `--strict`, para pegar link quebrado ou página fora da navegação, sem publicar nada.

O que o `--strict` costuma pegar é um link relativo apontando para uma página que mudou de nome ou uma página nova que ninguém citou na navegação, e descobrir isso antes do merge é bem mais barato do que depois de o site publicado perder a página.

O [rotate-secrets.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/rotate-secrets.yml) só roda por disparo manual, com um input `target`.

Esse input escolhe entre `sops-data-keys/cloudflare-tunnel-token/cloudflare-api-token/all`.

Os jobs correspondentes rodam sob o mesmo environment `rotate-secrets`, decifram com a identidade age da rotação e terminam abrindo um pull request em vez de fazer push direto em `main`.

A credencial trocada passa então pelos mesmos gates de qualquer outra mudança antes de chegar à branch principal.

## Como cada job obtém sua ferramenta

Nenhum job instala nada no runner. Cada ferramenta é um stage de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile), construído pela action composta [.github/actions/tool-image](https://github.com/guesant/hl-infrastructure/tree/main/.github/actions/tool-image) com o cache do GitHub Actions por stage, então uma imagem só é reconstruída quando o Dockerfile muda.

A action termina rodando o comando de versão da ferramenta dentro da imagem, antes de qualquer scan: uma imagem quebrada aparece como imagem quebrada, e não como um lint que passou verde porque não rodou nada.

Localmente o `justfile` faz o mesmo, taggeando cada imagem pelo hash do Dockerfile e pulando o build quando a tag já existe.

O stage `ops` reúne `sops/age/age-plugin-se/kubectl/jq/yq` numa única imagem Alpine.

`sops-recipients/security-sopssecrets/freeze` precisam de algum subconjunto delas e rodam inteiras em Docker, nunca no host.

O `KUBECTL_VERSION` desse stage é fixado à mão para ficar dentro de uma versão minor de `k3s_version`.

Um `kubectl` fora dessa janela de compatibilidade pode ter manifestos rejeitados pelo API server, por causa do version skew que o próprio Kubernetes declara entre cliente e servidor.

Um bump manual do `KUBECTL_VERSION` sem olhar `k3s_version` junto passaria despercebido por todo o resto do lint, até quebrar algum apply em produção.

`sops-recipients` não trata `.sops.yaml` como um número fixo de destinatários: cada entrada é só uma chave pública age com um rótulo em comentário.

Os subcomandos `add/update/remove/list` operam por rótulo, então adicionar uma chave nova, trocar uma existente ou remover qualquer uma delas, incluindo a do node, é a mesma operação.

Não há um esquema rígido de chave do node mais chave de backup para acomodar, e por isso nenhum papel fixo precisa ser inventado quando uma chave entra.

`sops-sync` é diferente: roda sempre no host, porque cifrar um `SopsSecret` novo e resincronizar os destinatários de um já cifrado são o mesmo comando, e o segundo precisa decifrar antes de regravar.

`sops-rotate` também roda só no host, sem exceção: gerar uma DEK nova para um arquivo cifrado sempre parte de decifrar o valor atual, mesmo quando os destinatários não mudaram em nada.

`age-plugin-se` funciona sem Secure Enclave só quando o objetivo é cifrar para um destinatário `age1se1...` que já existe, isso é uma operação pública, roda em qualquer Linux; decifrar de verdade só acontece no Mac que gerou a identidade.

Por isso `sops-sync` só exige `SOPS_AGE_KEY_FILE` (a identidade que decifra) no momento em que encontra um arquivo já cifrado que precisa ser resincronizado: cifrar um arquivo novo continua sem tocar em chave privada nenhuma, só que agora dentro do mesmo comando, e não mais numa recipe à parte.

As recipes `sops-sync/sops-rotate` do justfile fixam `SOPS_AGE_KEY_FILE` na identidade da Secure Enclave do operador por padrão.

Isso é diferente das demais recipes, que só usam essa identidade quando a variável ainda não está definida no ambiente.

Sem esse padrão fixo, `just sops-sync` sozinho, sem a variável exportada antes, falhava assim que encontrava o primeiro arquivo já cifrado para resincronizar.

## Os jobs

`actionlint/zizmor` auditam os próprios workflows do GitHub Actions: actionlint por erros de sintaxe e lógica, zizmor por padrões inseguros conhecidos (permissões excessivas, injeção via template, checkout sem `persist-credentials: false`).

A única auditoria do zizmor desligada, em [.github/zizmor.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/zizmor.yml), é a `self-repository`, que pede a sintaxe `$/` para a action local.

O actionlint ainda não aceita essa sintaxe, então ligá-la trocaria um lint verde por outro vermelho. Entre as duas, o `./` continua sendo o que o GitHub documenta como padrão.

`yamllint/ansible-lint` cobrem todo YAML do repositório e, em particular, o playbook e as roles, no perfil `production` do ansible-lint.

Isso exige nome de role e de variável com o prefixo da role, permissão explícita em todo arquivo criado, e `changed_when` em todo comando.

A única exclusão do yamllint, em [.config/yamllint.yml](https://github.com/guesant/hl-infrastructure/blob/main/.config/yamllint.yml), é `*.sops-secret.yaml`: o próprio SOPS escreve a indentação e a linha do `mac:` desses arquivos, e nem uma nem outra seguem a convenção deste repositório, então não há nada de útil pra este lint checar ali.

A exceção declarada é a regra `no-handler`, marcada com `noqa` nas tasks que precisam rodar no meio do play (o reboot depois de ligar o cgroup e o restart do Cilium depois de mudar a configuração), porque um handler só rodaria no fim.

`shellcheck` cobre todo script em `.tools/`, o único lugar do repositório com Bash de verdade, incluindo os próprios scripts que os outros jobs desta página rodam.

`hadolint` audita o [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) que constrói a imagem de cada uma dessas ferramentas.

As únicas regras desligadas, `DL3008/DL3018`, pedem para pinar a versão exata de cada pacote `apt/apk` instalado.

Cada estágio deste Dockerfile é uma imagem efêmera de CI, não um artefato publicado, então a versão exata de um pacote de sistema como git ou bash não é um input de supply chain que valha a pena travar.

`prose/spelling/markdownlint` cuidam da documentação.

O primeiro é o [.tools/check-prose.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-prose.sh), que falha se houver travessão, meia-risca ou seta Unicode em qualquer Markdown, a convenção descrita em [convenções de escrita](../contribuindo/convencoes-de-escrita.md).

`cspell` confere a ortografia em português e inglês, com o dicionário do projeto em [.config/cspell-words.txt](https://github.com/guesant/hl-infrastructure/blob/main/.config/cspell-words.txt) para o jargão que nenhum dicionário conhece.

`markdownlint-cli2` cobre o que os outros não cobrem: a estrutura do próprio Markdown, como bloco de código sem linguagem declarada, cabeçalho fora de ordem ou lista malformada.

As regras `MD013/MD033` (limite de comprimento de linha e proibição de HTML inline) ficam desligadas em [.config/.markdownlint-cli2.jsonc](https://github.com/guesant/hl-infrastructure/blob/main/.config/.markdownlint-cli2.jsonc).

A convenção de prosa deste repositório é parágrafo corrido sem quebra manual de linha, e o `README.md` usa uma tag `<a><img>` para o selo de licença GPLv3.

A verificação de links (`just lint-links`, com lychee) é o gate de documentação que ficou de fora da CI.

Sites externos devolvem `403` a robôs, derrubam a conexão ou demoram de forma imprevisível, e um gate que falha por causa de terceiros ensina a ignorar o gate. Por isso ela roda à mão, antes de uma mudança grande na documentação.

O custo assumido é que um link externo pode ficar quebrado no site até a próxima rodada manual, o que é aceitável porque nenhum link externo participa do funcionamento do cluster.

`gitleaks` varre todo o histórico do git em busca de segredo commitado por engano, incluindo regras próprias para uma chave privada age e para o arquivo de identidade do age-plugin-se, além das regras padrão.

Essas regras próprias reconhecem os prefixos `AGE-SECRET-KEY-1.../AGE-PLUGIN-SE-1...`.

`osv-scanner/trivy` (modo fs) procuram dependências com vulnerabilidade conhecida. Hoje nenhum dos dois encontra nada, porque o repositório não tem manifesto de dependência em nenhum ecossistema que eles entendam.

Esse é o resultado esperado, não uma falha de cobertura, e ele muda no dia em que algum código de aplicação entrar aqui.

`sopssecrets` roda [.tools/check-sopssecrets-encrypted.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-sopssecrets-encrypted.sh) para todo manifesto `*.sops-secret.yaml`.

Ele confere isso em toda a pasta `argocd/`.

Ele confere que existe um bloco `sops:`.

Confere também que todo valor sob `spec.secretTemplates[].stringData` é `ENC[...]`.

O conjunto de destinatários do arquivo precisa bater com `.sops.yaml`.

Um `SopsSecret` em texto claro, ou cifrado para um destinatário que já saiu do arquivo de destinatários, falha aqui, antes de chegar ao Argo.

O mesmo script confere os arquivos `tofu/**/*.sops.env`, que guardam as credenciais do OpenTofu num formato de ambiente em vez de SopsSecret.

Cada linha fora dos metadados do SOPS precisa ter valor `ENC[...]`, e os destinatários também precisam bater com `.sops.yaml`.

O mesmo job confere `ansible/group_vars/all/secrets.sops.yaml`: todo valor precisa ser `ENC[`.

Os destinatários desse arquivo também precisam bater com `.sops.yaml`.

Localmente, as recipes que chamam `ansible-playbook` passam a identidade da Secure Enclave em `SOPS_AGE_KEY_FILE` (ou a que já estiver no ambiente, como a chave de recuperação).

Isso é necessário porque o vars plugin da community.sops decifra esse arquivo ao carregar as variáveis.

`ast-grep` aplica regras estruturais próprias, declaradas em [.config/ast-grep](https://github.com/guesant/hl-infrastructure/tree/main/.config/ast-grep), sobre todo YAML, HCL e shell do repositório, e o mesmo job roda [.tools/check-dockerfile-comments.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-dockerfile-comments.sh), que aplica a regra de comentários a Dockerfile, uma linguagem que o ast-grep não analisa.

As regras declaradas ali exigem o seguinte: todo apply de chart Helm precisa de `--server-side --force-conflicts`, e toda task de comando precisa de `changed_when` explícito.

Nenhum comentário narrativo é permitido fora de uma diretiva de ferramenta.

Toda task `ansible.builtin.shell` que faça pipe para `k3s kubectl` precisa disso.

A flag exigida é `set -o pipefail`.

A última existe porque, sem ela, um `helm template` que falhe no meio do pipe fica mascarado pelo exit code do `kubectl`, que roda por último e normalmente retorna 0.

A regra de comentário em HCL ignora `.terraform.lock.hcl`, que o próprio `tofu init` escreve e assina com o aviso de que edição manual se perde no próximo init.

`jscpd` reporta duplicação de código entre as roles, sem falhar o build por isso; a duplicação entre as roles de instalação de chart (`cilium/argocd`) é intencional, não um erro a corrigir.

As duas repetem a mesma sequência de puxar o chart, conferir o checksum declarado em `versions.yml` e renderizar com `helm template`, e unificá-las custaria uma abstração que esconderia justamente os pontos em que elas diferem.

O relatório continua servindo como sinal: uma duplicação nova que não seja essa merece um olhar antes de virar a terceira cópia.

`helm-lint` roda [.tools/lint-charts.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/lint-charts.sh) antes da renderização, direto sobre a fonte de cada chart wrapper local em `argocd/apps`.

Ele confere convenção de nome, `Chart.yaml` bem formado, e template que não quebra o parser do Helm.

Isso alcança os charts de `operators//platform//data/`, como cert-manager, CNPG, sops-secrets-operator, Kargo e blog-postgres, e também as peças do satélite blog, que são blog, cloudflared, network-policies e delivery.

É complementar, não redundante, ao trio a seguir, que só enxerga o resultado já renderizado.

`kube-linter/checkov/trivy` (modo config) primeiro renderizam os charts Helm que este cluster usa, depois checam o resultado contra um conjunto restrito de regras.

O kube-linter roda com `doNotAutoAddDefaults` e só um conjunto restrito de checks ligados, resumidos na tabela abaixo.

| Ferramenta | Checks ligados |
| --- | --- |
| kube-linter | `privileged-container`, `host-network`, `host-pid`, `host-ipc`, `sensitive-host-mounts`, `unsafe-sysctls`, `non-existent-service-account` |
| checkov | `CKV_K8S_16`, `18` e `19` (privilegiado, PID e IPC do host) |

O conjunto padrão de cada ferramenta fica de fora de propósito: ele cobre limites de recursos, probes, `runAsNonRoot` e afins, decisões que pertencem ao chart de terceiro instalado, não a este repositório; falhar o gate por elas só produziria uma lista de exceções que ninguém revisa.

O Cilium fica de fora até desse conjunto restrito: uma CNI legitimamente precisa desses privilégios para funcionar, e sinalizar isso como problema seria ruído, não sinal.

Essas ferramentas checam só as pastas `argocd/root, argocd/applications`, nunca `argocd/apps`.

Essa última pasta guarda o código-fonte dos charts wrapper locais (`Chart.yaml/values.yaml`, o chart vendorizado), não manifesto Kubernetes, e um `kind` ausente ali é esperado, não um erro.

O `trivy config` também roda o scanner de Terraform, que alcança `tofu/` sem renderização nenhuma.

O job `tofu` roda `tofu fmt -check, tofu validate` sobre cada módulo.

Isso vale para cada módulo em `tofu/`.

Ele também roda as políticas do Conftest em `.config/conftest/tofu`.

Ele roda com `init -backend=false` e uma passphrase fictícia só para satisfazer a configuração de cifragem do state, sobre uma cópia do módulo sem o `terraform.tfstate` cifrado, que o init tentaria ler.

Vale saber o limite: as regras do trivy para recursos da Cloudflare são poucas, então um scan limpo ali diz mais sobre ausência de erro grosseiro de HCL do que sobre a configuração do túnel estar certa.

O passo `conftest`, dentro do mesmo job tofu, aplica as políticas de `.config/conftest/tofu` sobre um caminho amplo.

Esse caminho é `tofu/*/*.tf`.

Isso vale para qualquer módulo, e não só para o da Cloudflare.

As regras genéricas, cifragem do state com `enforced` e provider pinado em versão exata, valem para qualquer módulo que venha a existir em `tofu/`.

As que só descrevem recursos da Cloudflare simplesmente não casam com os outros, então aplicar o diretório inteiro não custa falso positivo nenhum.

`docs-consistency` fecha o ciclo entre código e documentação com um par de checks. Um deles, [.tools/check-doc-drift.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-doc-drift.sh), lê o marcador `source-of-trust` que algumas páginas carregam com os caminhos que descrevem, e falha quando o último commit que tocou esses caminhos não é ancestral do último commit que tocou a página: a fonte mudou e a página não foi revisada.

`.tools/docker/Dockerfile` e as pastas `.github/workflows, .github/actions` ficam de fora desse marcador nesta página de propósito.

O Renovate bumpa versão de imagem e de action pinada por SHA nesses caminhos todo dia, e um bump de versão isolado não muda nada que esta página descreva.

Rastrear esses caminhos fazia todo PR do Renovate falhar o gate por um motivo que não é dele resolver.

A página de OpenTofu segue a mesma lógica: rastreia os `.tf, terraform.tfvars` e os scripts.

Ela não rastreia os arquivos cifrados, o `terraform.tfstate` nem o `.terraform.lock.hcl`, que mudam a cada troca de segredo, a cada apply e a cada bump do Renovate sem mudar nada que a página descreve.

Uma ferramenta nova de verdade sempre toca `justfile`, que continua rastreado, porque a convenção deste repositório é toda ferramenta de CI ter uma receita local correspondente.

O outro check do mesmo job, [.tools/check-roles-documented.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-roles-documented.sh), falha se existir uma role em `ansible/roles` sem parágrafo em [Ansible: as roles do bootstrap](ansible.md), ou uma role em `site.yml` que não existe.

São os dois sentidos da mesma inconsistência: código que ninguém documentou e documentação que aponta para o que já saiu.

O preço de mantê-lo é um parágrafo por role nova, e o que ele evita é a página de roles envelhecer em silêncio, que é como uma documentação de infraestrutura deixa de ser lida.

`kubeconform` valida os mesmos manifestos renderizados, mais as pastas `argocd/root, argocd/applications`, contra o schema da API do Kubernetes e contra o catálogo público de schemas de CRDs, em modo estrito.

Um campo com nome errado num `Application` ou num `Cluster` do CloudNativePG falha aqui, antes de chegar ao Argo, em vez de ser silenciosamente ignorado pelo apply.

Um schema que não existe no catálogo é pulado, não tratado como erro, para que uma CRD nova não bloqueie o gate.

Os `kind` do Kargo (`Project/Warehouse/Stage/ProjectConfig`) caem nesse caso enquanto o catálogo não os tiver.

O mesmo job termina com um check próprio, em [.tools/check-images-pinned.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-images-pinned.sh), que falha se qualquer `image:` renderizada vier sem tag nem digest: uma imagem sem tag resolve para `latest` no pull e muda sem deixar rastro no git.

A metade em texto claro dessa verificação roda na CI, no job `placeholders` ([.tools/lint-placeholders.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/lint-placeholders.sh)), e falha em qualquer valor de exemplo que sobrar em qualquer arquivo do repositório, docs incluídas.

O critério é o formato de valor, não a menção: um `REPLACE_WITH_` seguido de nome, um hostname completo sob o domínio reservado `.invalid`.

Também conta um changeme seguido de separador, e a tag de imagem só com zeros.

Por isso um script que testa se algo começa com `REPLACE_WITH_`, ou uma página que explica a convenção, passa sem exceção nenhuma.

Os arquivos `.example.` ficam de fora porque são modelos por definição.

Uma linha que precisa citar um valor de exemplo literal, como a allowlist do `gitleaks.toml`, carrega a diretiva `placeholder-lint: ignore`.

O mesmo job confere que o hostname do blog é o mesmo no OpenTofu e no `PUBLIC_SITE_BASE_URL`.

O que a CI não enxerga é o conteúdo dos arquivos cifrados; isso continua com o `just placeholders` local, que roda este mesmo linter antes da parte que decifra.

O job `pod-security` ([.tools/check-namespace-pod-security.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-namespace-pod-security.sh)) protege uma regra que nenhum lint de manifesto enxerga.

Essa regra mora no `syncPolicy` das `Application` e não nos charts renderizados.

Todo namespace que uma aplicação cria com `CreateNamespace=true` precisa ter o label `pod-security.kubernetes.io/enforce`.

Esse label vem seja no `managedNamespaceMetadata` de quem o cria, seja num manifesto Namespace sob `argocd/apps`, que é o caminho para um namespace de satélite, cujo projeto não pode alterar recurso de escopo de cluster.

O namespace `argocd` é a única exceção aceita, desde que a role `argocd` do Ansible aplique o label.

Sem esse job, um satélite novo nasceria num namespace sem Pod Security Admission e só os gates de chart impediriam um pod privilegiado, que é justamente o que o cluster não deveria depender só da CI para barrar.

O job `kubescape` roda os frameworks NSA e MITRE sobre os charts renderizados e sobre `argocd/`.

A nota fica abaixo do ideal, puxada por controles que os charts de terceiros não atendem (limites de recursos no Argo CD, `hostNetwork` e privilégio no Cilium, leitura de `Secret` pelos operadores), então o job não exige nota máxima.

A flag `--compliance-threshold`, declarada no justfile, trava a nota atual como piso, e qualquer mudança que a derrube falha o `gate`. Subir essa nota é o jeito de registrar uma melhora.

O job tofu espelha antes o provider do Keycloak com `.tools/tofu-mirror.sh`, porque o registro do OpenTofu não consegue verificar a assinatura dele e o `validate` precisa do binário.

O zip é conferido contra o `SHA256SUMS` da release e contra o lock file. A alternativa seria mandar o `init` ignorar a verificação do provider, o que trocaria uma falha visível por uma confiança que ninguém declarou em lugar nenhum.

O job `trivy-images` lista toda imagem que o cluster roda a partir de `.build/rendered/` e argocd/ ([.tools/list-images.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/list-images.sh)).

Ele gera um SBOM CycloneDX por imagem, publicado como artefato do run pelo prazo de retenção configurado, e falha em qualquer CVE crítica que já tenha correção.

O scanner roda cross-platform (`--platform linux/arm64` num runner amd64).

De vez em quando isso deixa uma layer truncada no volume `trivy-cache` compartilhado, sobra de um pull interrompido, que faz o trivy sair com um erro `FATAL` sem nenhuma relação com vulnerabilidade real.

A função `run_trivy_retrying`, em [.tools/trivy-images.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/trivy-images.sh), detecta esse FATAL especificamente, apaga o volume trivy-cache e tenta de novo uma vez, para que o exit code 1 sempre signifique um achado real de CVE, nunca uma cache corrompida.

As exceções vivem em [.trivyignore.yaml](https://github.com/guesant/hl-infrastructure/blob/main/.trivyignore.yaml), cada uma com o motivo e uma data `expired_at`: passada a data, a CVE volta a derrubar o job, então uma exceção nunca vira permanente sem alguém decidir de novo.

As imagens que o k3s embute no próprio binário (CoreDNS, metrics-server, local-path-provisioner) ficam de fora, porque não aparecem em nenhum manifesto do repositório e só mudam com a versão do k3s.

Os hooks de git versionados vivem em `.config/githooks`, junto das outras configurações de ferramenta, e `just hooks` aponta o core.hooksPath para lá.

O job `commitlint` confere cada commit do push ou da pull request contra [.config/commitlint.config.mjs](https://github.com/guesant/hl-infrastructure/blob/main/.config/commitlint.config.mjs), a mesma convenção do [CONTRIBUTING](https://github.com/guesant/hl-infrastructure/blob/main/CONTRIBUTING.md): tipo permitido, título de até 72 caracteres sem ponto final, sem corpo e sem rodapé.

O hook `.githooks/commit-msg`, ligado com `just hooks`, roda a mesma checagem antes de o commit existir.

O job `domain-expiry` consulta o RDAP do domínio do blog ([.tools/check-domain-expiry.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-domain-expiry.sh)): num push só avisa quando o prazo está próximo, e na execução agendada falha quando está mais próximo ainda.

Ele fica fora do `gate` pelo mesmo motivo do `secret-age`. Um domínio vencido derruba de uma vez tudo o que está atrás dele, e a correção é uma renovação no registrador, não um deploy, então o aviso precisa chegar antes de a data virar falha.

O job `manifest-diff` roda só em pull request. Ele faz checkout da base e da cabeça do PR lado a lado, renderiza os charts em ambas com o mesmo `.tools/render-charts.sh`.

Ele publica no resumo da execução o diff do que foi renderizado e da pasta argocd/ ([.tools/render-diff.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/render-diff.sh)).

É o substituto de um `argocd app diff` na CI: o `app diff` compararia com o que está vivo no cluster, mas exigiria expor a API do Argo CD para a internet e guardar um token dele no GitHub, mesmo que só de leitura, e o servidor do Argo hoje só é alcançável pela rede local.

O diff renderizado não vê deriva do cluster, que o `selfHeal` já corrige, mas mostra exatamente o que o merge vai mandar o Argo aplicar. Ele fica fora do `gate` porque não reprova nada, só informa.

O mesmo script passa `--api-versions monitoring.coreos.com/v1` ao renderizar o ingress, porque o chart do Traefik só emite o `ServiceMonitor` quando o cluster tem essa API, e a renderização local não tem cluster para consultar.

O job `secret-age` ([.tools/check-secret-age.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-secret-age.sh)) fica fora do `gate` de propósito.

Ele lê a data lastmodified que o SOPS grava em texto claro em todo arquivo cifrado, sem precisar de chave, e compara com o prazo de [.config/secret-max-age.conf](https://github.com/guesant/hl-infrastructure/blob/main/.config/secret-max-age.conf).

Num push ou pull request, um arquivo vencido só vira aviso na execução; na execução agendada diária o job falha, o workflow fica vermelho e o GitHub notifica por e-mail.

Assim um segredo vencido nunca bloqueia um deploy urgente, e também não passa semanas sem ninguém ver.

O limite dessa medida está em [rotacionar credenciais](../operacional/rotacionar-credenciais.md): o prazo é por arquivo, não por valor, e `just sops-rotate` zera o relógio sem trocar o segredo. Veja [OpenTofu: a camada da Cloudflare](opentofu.md).

O mesmo job também roda [.tools/check-security-review.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/check-security-review.sh), com a mesma divisão entre aviso e falha, contra a data da última [revisão periódica](../operacional/revisao-periodica.md) gravada em [.config/security-review.conf](https://github.com/guesant/hl-infrastructure/blob/main/.config/security-review.conf).

Localmente, `just lint-security-review` mostra quantos dias faltam.

Nenhuma recipe que decifra roda na CI, porque todas precisam da identidade da Secure Enclave.

É o caso de `just webhook-secret`, que imprime o segredo do webhook do GitHub para configurá-lo à mão.

É também o caso de `just sops-edit`, usado para editar `k3s_join_token` antes de uma rotação.

O job `sopssecrets` só confere, sem chave, que esses arquivos continuam cifrados.

## Por que um workflow só

Um job separado para cada ferramenta exigiria uma entrada na branch protection para cada um deles, sem nenhum lugar único que respondesse à pergunta "este push está OK para mergear".

Um workflow só, com um job `gate` no final, resolve isso sem abrir mão de isolamento por job: cada job mantém seu próprio `permissions:`.

`contents: read` fica no topo do arquivo, e escopos mais amplos como `security-events: write` só onde o job precisa.

O `gate` não precisa saber nada sobre o que cada ferramenta faz, só se algum `needs` falhou.

É esse único job que faz sentido marcar como obrigatório na branch protection, em vez da lista inteira, que cresce a cada gate novo.

## Nada entra sem digest ou checksum

Toda dependência que o repositório baixa tem uma identidade fixa no git, e o que não pode ter é dito aqui.

Imagens de contêiner, nas `Application`, nos values das roles e no Dockerfile das ferramentas, vêm com `@sha256`.

O check `check-images-pinned.sh` recusa uma imagem só com tag, mesmo nos charts que o Ansible instala, porque o `render-charts.sh` os renderiza com os mesmos values da role.

As `uses:` dos workflows são SHA de commit.

A imagem do OpenTofu no justfile e a do actionlint no `ci.yml` levam digest, e o Renovate as acompanha por gerenciadores de regex que capturam versão e digest juntos.

As ferramentas instaladas dentro do Dockerfile não usam mais `pip install pacote==versão` nem `npm install --global`.

Cada uma tem um `requirements.txt` com `--require-hashes`.

Esse arquivo é gerado por `pip-compile --generate-hashes` a partir do arquivo `.in` correspondente.

Esses arquivos `.in` vivem em `.tools/docker/pip`.

Ou um `package-lock.json` com `integrity`.

Esse arquivo vive em `.tools/docker/npm`, instalado com `npm ci`.

O Renovate atualiza esses arquivos pelos gerenciadores nativos.

O `kubectl` e o age-plugin-se baixados na imagem ops são conferidos contra um SHA-256, o primeiro publicado pelo projeto e o segundo fixado no `Dockerfile`.

A carência padrão que o Renovate espera antes de propor qualquer bump tem uma exceção deliberada: as tags `node/python/alpine`, as imagens base rolantes do Dockerfile de ferramentas, ficam com `minimumReleaseAge` desligado.

Essas tags são republicadas com frequência e nunca acumulariam carência suficiente paradas; sem a exceção, essas imagens nunca seriam atualizadas de forma automática.

Do lado do node, o binário do k3s, o Helm e o `cilium-cli` sempre foram conferidos contra o checksum publicado.

Passaram a ser também o script de instalação do k3s, baixado da tag e não de `get.k3s.io`, conferido contra `k3s_install_script_sha256`.

E a chave apt do Tailscale, contra `tailscale_apt_key_sha256`.

Os charts do Argo CD e do Cilium entraram na mesma regra: o Ansible os puxa para `/etc/rancher/charts`, confere contra `argocd_chart_sha256/cilium_chart_sha256` e só então renderiza.

O `render-charts.sh` repete a conferência na CI, então um bump de versão do Renovate sem o digest novo fica vermelho até alguém revisar o chart e atualizar `versions.yml`.

O que fica sem hash tem motivo declarado. Os pacotes das distribuições (`apk`, `apt`) são assinados pelo repositório da distribuição e fixados pela imagem base por digest ou pela release da Debian.

A coleção `ansible.posix` vem do Galaxy só com versão, porque o ansible-galaxy não confere checksum de coleção.

Os índices dos repositórios Helm são consultados a cada `pull`, mas o que se instala dali é o arquivo conferido.

## Rodando localmente

Cada job tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda o mesmo comando; veja [rodar os quality gates localmente](../operacional/rodar-quality-gates-localmente.md).

A recíproca não vale: o justfile também tem recipes que mudam o node ou o cluster de verdade (`bootstrap/rotate-certs/rotate-token/rotate-age-key`), sem job de CI correspondente, porque não são coisa pra rodar a cada push, só quando o operador decide, à mão.

Nenhuma delas pede senha, porque o inventário conecta como `root`; veja [rotacionar credenciais](../operacional/rotacionar-credenciais.md).

O OpenTofu é a exceção de imagem: todas as receitas dele (`lint-tofu/tofu/tofu-apply/tofu-plan-all/tofu-apply-all/cloudflare-tunnel-token`) usam direto a imagem oficial `ghcr.io/opentofu/opentofu`.

Essa imagem, ao contrário das demais, não pode virar um stage do Dockerfile compartilhado: desde a versão 1.10 ela recusa deliberadamente ser usada como base de outra imagem.

Só `lint-tofu` tem job correspondente na CI; as outras mexem em infraestrutura real fora do cluster e dependem de decifrar segredo com a identidade do operador, então ficam no mesmo grupo de `bootstrap/rotate-*`.

`tofu-plan-all/tofu-apply-all` só repetem `tofu/tofu-apply` em sequência.

Isso vale um módulo de cada vez, para cada módulo em `tofu/`.

Cada apply roda um de cada vez, confirmando por conta própria como sempre confirmou.

`tofu-list` é a exceção: só lista os nomes dos módulos existentes, sem tocar em segredo nem em imagem nenhuma.

`tofu-state-passphrase`, que gera ou rotaciona a passphrase do state, também fica fora da CI: roda no host, como `sops-sync`.

O mesmo vale para `placeholders`, que precisa decifrar todo arquivo SOPS para saber o que ainda é valor de exemplo.

O `justfile` também carrega recipes que a CI nunca roda porque exigem a identidade do operador, como `keycloak-bootstrap-admin/keycloak-user/keycloak-rotate-admin`.

Elas aposentam o administrador temporário do Keycloak, criam usuários humanos nos realms e rotacionam a senha do administrador que o OpenTofu usa, falando só com a API do Keycloak pela tailnet, sem precisar do `kubectl`.

Também ficam nesse grupo `kubectl/status/internal-ca/freeze-manifest/pv-relink`, que rodam o `kubectl` no próprio node por SSH, porque a API do k3s não é alcançável de nenhuma rede.

Elas ficam no mesmo arquivo para que `just --list` seja o inventário completo do que se pode fazer com o repositório.

Outra categoria ainda não precisa nem de identidade nem de cluster: `satellite-add/satellite-delivery-add`.

Elas só editam o `values.yaml` de um chart local com `yq/jq`.

Elas rodam dentro do `{{ops_image}}`, que já traz essas ferramentas, embora não precisem de nenhum segredo, o mesmo que [adicionar um satélite](../operacional/adicionar-um-satelite.md) descreve por extenso; ficam fora da CI, mas por não ter o que verificar antes de existir um `git diff` para revisar.

`docs-prose-stats`, sobre [.tools/prose-stats.py](https://github.com/guesant/hl-infrastructure/blob/main/.tools/prose-stats.py), fica pelo mesmo motivo do lado oposto: mede sentenças por parágrafo, crases por sentença e diagramas mermaid por página, para achar onde a prosa fragmentou demais ou saturou de crase, mas não define um limiar certo o bastante para falhar sozinho um gate, então é ferramenta de quem revisa a prosa, não parte do `check`.

## Continue por aqui

[Rodar os quality gates localmente](../operacional/rodar-quality-gates-localmente.md) mostra como reproduzir qualquer um destes jobs no próprio Mac antes de dar push.
