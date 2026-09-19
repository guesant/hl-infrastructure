# A pipeline de CI

<!-- source-of-trust paths="justfile .config/kube-linter.yaml" -->

O workflow de CI roda em todo push em `main` e em todo pull request, com todos os jobs em paralelo. Um último job, o gate, depende de todos os outros e falha se qualquer um deles falhar ou for cancelado. É esse único job, e não a lista inteira, que faz sentido marcar como check obrigatório na branch protection.

Num pull request nem todo job roda. Um job inicial detecta que áreas o PR toca, e os jobs caros ou específicos só rodam quando a área correspondente muda.

| Área que mudou | Jobs que rodam |
| --- | --- |
| `argocd/`, `ansible/`, `.tools/`, `.config/` ou o `justfile` | A família que renderiza os charts: lint de Helm, kube-linter, checkov, kubeconform, trivy de configuração, kubescape, trivy de imagens, segurança de Pod, segredos cifrados |
| `ansible/` | ansible-lint |
| `tofu/` ou seus scripts e políticas | O job de OpenTofu |
| Doc ou Markdown | markdownlint |
| `.tools/` | hadolint, shellcheck |

Os jobs que olham o repositório inteiro (segredos vazados, dependência vulnerável, trivy de sistema de arquivos, prosa, placeholders, consistência de docs, regras estruturais, duplicação de código e convenção de commit) rodam sempre. Em push para `main`, no agendamento diário e no disparo manual, tudo roda, filtro nenhum se aplica; o filtro existe só para encurtar o ciclo de um PR, nunca para deixar `main` passar sem a bateria inteira.

Um job pulado aparece como sucesso na tabela do gate; falha e cancelamento continuam derrubando o gate. A concorrência é por ref: um push novo no mesmo PR cancela o run anterior, enquanto runs de `main` nunca são cancelados. A distinção entre os dois estados é o que permite o filtro de caminhos existir sem afrouxar o gate: pular é uma decisão declarada, e ser cancelado é uma interrupção, que nunca conta como verificação feita.

Alguns jobs guardam estado entre runs com o cache do GitHub Actions, além das camadas das imagens de ferramenta: as coleções do Galaxy que o ansible-lint instala, o banco de vulnerabilidades do trivy, com restauração do mais recente porque o banco muda todo dia e o trivy o atualiza sozinho quando está velho, o cache de schemas do kubeconform e o espelho de providers do OpenTofu.

Nada disso muda o que é verificado; só evita baixar de novo o que não mudou.

## Os demais workflows

Cobertura de segurança, qualidade estrutural e lint de infraestrutura vivem no [ci.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/ci.yml); os workflows que ficam fora dele cuidam da manutenção deste repositório. Nenhum deles entra no `gate`, porque nenhum verifica a mudança em revisão: eles publicam a nota de práticas do repositório, abrem pull requests de atualização, constroem este site e rotacionam credenciais sob disparo manual.

A consequência é que uma falha em qualquer um deles não bloqueia um merge, e aparece só como workflow vermelho na aba de Actions.

O [scorecard.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/scorecard.yml) roda o OpenSSF Scorecard a cada push em `main`, toda segunda-feira e a cada mudança de proteção de branch. Ele avalia práticas do repositório, como proteção de branch, actions pinadas por SHA e permissões mínimas dos workflows, publica a nota que o selo do README mostra e envia os achados para o code scanning do GitHub.

Só esse job ganha permissão de escrita em eventos de segurança e um token de identidade, este último para o Scorecard provar ao serviço de publicação que o resultado veio deste repositório.

O [renovate.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/renovate.yml) roda self-hosted todo dia de manhã, isolado num environment restrito à branch principal, e bumpa a versão de cada chart Helm diretamente no arquivo de versões real que o Ansible lê. Num push em `main` ele só roda quando o push muda a própria configuração do Renovate, para validar a mudança sem esperar o dia seguinte.

Rodar a cada push custava um tempo real por commit, e o ganho era atualizar na hora uma PR do Renovate que conflitasse com um push admin em `main`; com um operador só, esse conflito pode esperar a janela agendada da manhã seguinte, ou um disparo manual.

O [docs.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/docs.yml) constrói este site com MkDocs e publica no GitHub Pages quando o push é em main, mas só quando o push toca o que o build lê. Os links das páginas para o código são URLs absolutas do GitHub, então mudar um script ou um manifesto não muda o site; em pull requests, ele só constrói em modo estrito, para pegar link quebrado ou página fora da navegação, sem publicar nada.

O que o modo estrito costuma pegar é um link relativo apontando para uma página que mudou de nome ou uma página nova que ninguém citou na navegação, e descobrir isso antes do merge é bem mais barato do que depois de o site publicado perder a página.

O [rotate-secrets.yml](https://github.com/guesant/hl-infrastructure/blob/main/.github/workflows/rotate-secrets.yml) só roda por disparo manual, escolhendo entre os alvos de rotação disponíveis. Os jobs correspondentes rodam sob o mesmo environment de rotação, decifram com a identidade age correspondente e terminam abrindo um pull request em vez de fazer push direto em `main`. A credencial trocada passa então pelos mesmos gates de qualquer outra mudança antes de chegar à branch principal.

## Como cada job obtém sua ferramenta

Nenhum job instala nada no runner. Cada ferramenta é um stage de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile), construído por uma action composta com o cache do GitHub Actions por stage, então uma imagem só é reconstruída quando o Dockerfile muda. A action termina rodando o comando de versão da ferramenta dentro da imagem, antes de qualquer scan: uma imagem quebrada aparece como imagem quebrada, e não como um lint que passou verde porque não rodou nada.

Localmente o `justfile` faz o mesmo, taggeando cada imagem pelo hash do Dockerfile e pulando o build quando a tag já existe.

Um dos estágios reúne várias ferramentas de segredo e Kubernetes numa única imagem Alpine, porque algumas recipes precisam de um subconjunto delas e rodam inteiras em Docker, nunca no host. A versão do `kubectl` desse estágio é fixada à mão para ficar dentro de uma versão minor da versão do k3s: um `kubectl` fora dessa janela de compatibilidade pode ter manifestos rejeitados pelo API server, por causa do version skew que o próprio Kubernetes declara entre cliente e servidor.

Um bump manual de uma versão sem olhar a outra junto passaria despercebido por todo o resto do lint, até quebrar algum apply em produção.

A gestão de destinatários do SOPS não trata o arquivo de configuração como um número fixo deles: cada entrada é só uma chave pública age com um rótulo em comentário. Os subcomandos de adicionar, atualizar, remover e listar operam por rótulo, então adicionar uma chave nova, trocar uma existente ou remover qualquer uma delas, incluindo a do node, é a mesma operação.

Não há um esquema rígido de chave do node mais chave de backup para acomodar, e por isso nenhum papel fixo precisa ser inventado quando uma chave entra.

A sincronização de segredos é diferente: roda sempre no host, porque cifrar um `SopsSecret` novo e resincronizar os destinatários de um já cifrado são o mesmo comando, e o segundo precisa decifrar antes de regravar. A rotação de chave de segredo também roda só no host, sem exceção: gerar uma chave nova para um arquivo cifrado sempre parte de decifrar o valor atual, mesmo quando os destinatários não mudaram em nada.

O plugin de Secure Enclave funciona sem hardware dedicado só quando o objetivo é cifrar para um destinatário que já existe, uma operação pública que roda em qualquer Linux; decifrar de verdade só acontece no Mac que gerou a identidade. Por isso a sincronização só exige a identidade que decifra no momento em que encontra um arquivo já cifrado que precisa ser resincronizado: cifrar um arquivo novo continua sem tocar em chave privada nenhuma.

As recipes de sincronização e rotação do `justfile` fixam essa identidade na Secure Enclave do operador por padrão, ao contrário das demais recipes que só usam essa identidade quando a variável ainda não está definida no ambiente; sem esse padrão fixo, a recipe sozinha, sem a variável exportada antes, falhava assim que encontrava o primeiro arquivo já cifrado para resincronizar.

## Os jobs

| Job | O que faz |
| --- | --- |
| actionlint, zizmor | Auditam os próprios workflows: erro de sintaxe e lógica, e padrão inseguro conhecido (permissão excessiva, injeção via template, checkout sem persistir credencial) |
| yamllint, ansible-lint | Cobrem todo YAML, e em particular o playbook e as roles, no perfil mais rigoroso do ansible-lint |
| shellcheck | Cobre todo script em `.tools/`, o único lugar do repositório com Bash de verdade |
| hadolint | Audita o Dockerfile que constrói a imagem de cada ferramenta |
| prose | Falha se houver travessão, meia-risca ou seta Unicode em qualquer Markdown, a convenção de [convenções de escrita](../contribuindo/convencoes-de-escrita.md) |
| markdownlint | Cobre a estrutura do próprio Markdown: bloco de código sem linguagem declarada, cabeçalho fora de ordem, lista malformada |

A única auditoria do zizmor desligada é a que audita a própria action local, porque ela exige uma sintaxe de referência que o actionlint ainda não aceita; ligá-la trocaria um lint verde por outro vermelho.

A única exclusão do yamllint é o arquivo de segredo cifrado do SOPS: o próprio SOPS escreve a indentação e a linha de autenticação desses arquivos, e nenhuma das duas segue a convenção deste repositório, então não há nada de útil pra esse lint checar ali;

a exceção declarada é a regra que exige um handler em vez de uma tarefa reiniciando algo no meio do play, porque duas tarefas específicas (o reboot depois de ligar o cgroup, o restart do Cilium depois de mudar a configuração) precisam rodar ali mesmo, não no fim.

As duas regras desligadas do hadolint pedem para pinar a versão exata de cada pacote de sistema instalado; cada estágio do Dockerfile é uma imagem efêmera de CI, não um artefato publicado, então isso não é um input de supply chain que valha a pena travar.

As duas regras desligadas do markdownlint são o limite de comprimento de linha e a proibição de HTML inline: a convenção de prosa deste repositório é parágrafo corrido sem quebra manual, e o `README.md` usa uma tag de imagem para o selo de licença.

A verificação de links, com o lychee, é o gate de documentação que ficou de fora da CI. Sites externos devolvem erro a robôs, derrubam a conexão ou demoram de forma imprevisível, e um gate que falha por causa de terceiros ensina a ignorar o gate. Por isso ela roda à mão, antes de uma mudança grande na documentação.

O custo assumido é que um link externo pode ficar quebrado no site até a próxima rodada manual, o que é aceitável porque nenhum link externo participa do funcionamento do cluster.

| Job | O que faz |
| --- | --- |
| gitleaks | Varre todo o histórico do git em busca de segredo commitado por engano, incluindo regras próprias para os formatos de chave age deste repositório |
| osv-scanner, trivy (modo de sistema de arquivos) | Procuram dependência com vulnerabilidade conhecida; hoje não encontram nada porque o repositório não tem manifesto de dependência em nenhum ecossistema que eles entendam, resultado esperado, não falha de cobertura |
| sopssecrets | Confere que todo segredo cifrado do repositório (manifesto Kubernetes, arquivo de ambiente do OpenTofu, segredo do Ansible) está de fato cifrado e com os destinatários corretos, antes de chegar ao Argo |
| ast-grep | Aplica regras estruturais próprias sobre todo YAML, HCL e shell, mais uma regra de comentário sobre Dockerfile, linguagem que o ast-grep não analisa sozinho |
| jscpd | Reporta duplicação de código entre as roles, sem falhar o build por isso |

A regra do ast-grep mais específica exige que toda tarefa de shell que faça pipe para o kubectl do k3s declare a opção que propaga falha de qualquer estágio do pipe, porque sem ela uma renderização de chart que falhe no meio fica mascarada pelo exit code do kubectl, que roda por último e normalmente retorna sucesso.

A duplicação que o jscpd relata entre as roles de instalação de chart é intencional, não um erro a corrigir: as duas repetem a mesma sequência de puxar o chart, conferir o checksum declarado e renderizar, e unificá-las custaria uma abstração que esconderia justamente os pontos em que elas diferem; o relatório continua servindo como sinal para uma duplicação nova que não seja essa.

O `helm-lint` roda antes da renderização, direto sobre a fonte de cada chart wrapper local: convenção de nome, manifesto de chart bem formado, template que não quebra o parser do Helm. Isso alcança todos os charts de operador, plataforma e dado, e também as peças do satélite blog. É complementar, não redundante, ao trio seguinte, que só enxerga o resultado já renderizado.

O kube-linter, o checkov e o trivy de configuração primeiro renderizam os charts Helm que este cluster usa, depois checam o resultado contra um conjunto restrito de regras: só privilégio, rede e acesso de host do processo.

O conjunto padrão de cada ferramenta fica de fora de propósito: ele cobre limite de recursos, sondas e outras decisões que pertencem ao chart de terceiro instalado, não a este repositório; falhar o gate por elas só produziria uma lista de exceções que ninguém revisa. O Cilium fica de fora até desse conjunto restrito: uma CNI legitimamente precisa desses privilégios para funcionar, e sinalizar isso como problema seria ruído, não sinal.

Essas ferramentas checam só o root e as aplicações do Argo, nunca a pasta que guarda o código-fonte dos charts wrapper locais, porque essa última não é manifesto Kubernetes, e um tipo de recurso ausente ali é esperado, não um erro.

O trivy de configuração também roda o scanner de Terraform, que alcança o OpenTofu sem renderização nenhuma. O job correspondente valida a formatação e a sintaxe de cada módulo, além das políticas do Conftest, sobre uma cópia do módulo sem o state cifrado, que a inicialização tentaria ler.

Vale saber o limite: as regras do trivy para recursos da Cloudflare são poucas, então um scan limpo ali diz mais sobre ausência de erro grosseiro de HCL do que sobre a configuração do túnel estar certa.

O passo do Conftest, dentro do mesmo job, aplica as políticas do OpenTofu sobre todo módulo, e não só sobre o da Cloudflare. As regras genéricas, cifragem do state obrigatória e provider pinado em versão exata, valem para qualquer módulo que venha a existir. As que só descrevem recursos da Cloudflare simplesmente não casam com os outros, então aplicar o diretório inteiro não custa falso positivo nenhum.

`docs-consistency` fecha o ciclo entre código e documentação com um par de checks. Um deles lê o marcador que algumas páginas carregam com os caminhos que descrevem, e falha quando o último commit que tocou esses caminhos não é ancestral do último commit que tocou a página: a fonte mudou e a página não foi revisada.

O Dockerfile de ferramentas e os workflows ficam de fora desse marcador nesta própria página de propósito: o Renovate bumpa versão de imagem e de action pinada por SHA nesses caminhos todo dia, e um bump de versão isolado não muda nada que esta página descreva.

Rastrear esses caminhos fazia todo PR do Renovate falhar o gate por um motivo que não é dele resolver. A página de OpenTofu segue a mesma lógica: rastreia os arquivos de módulo e os scripts, mas não os arquivos cifrados nem o state, que mudam a cada troca de segredo, a cada apply e a cada bump do Renovate sem mudar nada que a página descreve.

Uma ferramenta nova de verdade sempre toca o `justfile`, que continua rastreado, porque a convenção deste repositório é toda ferramenta de CI ter uma receita local correspondente.

O outro check do mesmo job falha se existir uma role sem parágrafo em [Ansible: as roles do bootstrap](ansible.md), ou uma role referenciada que não existe mais. São os dois sentidos da mesma inconsistência: código que ninguém documentou e documentação que aponta para o que já saiu.

O preço de mantê-lo é um parágrafo por role nova, e o que ele evita é a página de roles envelhecer em silêncio, que é como uma documentação de infraestrutura deixa de ser lida.

O `kubeconform` valida os manifestos renderizados contra o schema da API do Kubernetes e contra o catálogo público de schemas de CRDs, em modo estrito: um campo com nome errado num recurso qualquer falha aqui, antes de chegar ao Argo, em vez de ser silenciosamente ignorado pelo apply.

Um schema que não existe no catálogo é pulado, não tratado como erro, para que uma CRD nova não bloqueie o gate; os tipos do Kargo caem nesse caso enquanto o catálogo não os tiver. O mesmo job termina com um check próprio que falha se qualquer imagem renderizada vier sem tag nem digest: uma imagem sem tag resolve para a mais recente no pull e muda sem deixar rastro no git.

A metade em texto claro dessa verificação roda na CI, e falha em qualquer valor de exemplo que sobrar em qualquer arquivo do repositório, docs incluídas. O critério é o formato de valor, não a menção: um placeholder de nome seguido de identificador, um hostname completo sob o domínio reservado, uma senha de exemplo seguida de separador e a tag de imagem só com zeros.

Por isso um script que testa se algo começa com o mesmo prefixo, ou uma página que explica a convenção, passa sem exceção nenhuma.

Os arquivos de exemplo ficam de fora porque são modelos por definição, e uma linha que precisa citar um valor de exemplo literal carrega uma diretiva própria de ignorar. O mesmo job confere que o hostname do blog é o mesmo no OpenTofu e na URL pública declarada. O que a CI não enxerga é o conteúdo dos arquivos cifrados; isso continua com a recipe local, que roda este mesmo linter antes da parte que decifra.

O job de segurança de Pod protege uma regra que nenhum lint de manifesto enxerga, porque ela mora na política de sincronização das aplicações e não nos charts renderizados: todo namespace que uma aplicação cria precisa ter o label de aplicação de Pod Security, seja na metadata de quem o cria, seja num manifesto de namespace próprio, que é o caminho para um namespace de satélite, cujo projeto não pode alterar recurso de escopo de cluster.

O namespace do Argo CD é a única exceção aceita, desde que a role correspondente do Ansible aplique o label. Sem esse job, um satélite novo nasceria num namespace sem Pod Security Admission e só os gates de chart impediriam um pod privilegiado, que é justamente o que o cluster não deveria depender só da CI para barrar.

O job de segurança geral roda os frameworks NSA e MITRE sobre os charts renderizados e sobre a pasta do Argo. A nota fica abaixo do ideal, puxada por controles que os charts de terceiros não atendem, então o job não exige nota máxima: uma flag declarada no `justfile` trava a nota atual como piso, e qualquer mudança que a derrube falha o gate. Subir essa nota é o jeito de registrar uma melhora.

O job de OpenTofu espelha antes o provider do Keycloak, porque o registro do OpenTofu não consegue verificar a assinatura dele e a validação precisa do binário. O zip é conferido contra o checksum da release e contra o lock file. A alternativa seria mandar a inicialização ignorar a verificação do provider, o que trocaria uma falha visível por uma confiança que ninguém declarou em lugar nenhum.

O job de trivy sobre imagens lista toda imagem que o cluster roda, gera um SBOM por imagem, publicado como artefato do run, e falha em qualquer vulnerabilidade crítica que já tenha correção.

O scanner roda entre arquiteturas diferentes, e de vez em quando isso deixa uma camada truncada no cache compartilhado, sobra de um pull interrompido, que faz o trivy sair com um erro fatal sem nenhuma relação com vulnerabilidade real; uma função própria detecta esse erro especificamente, apaga o cache e tenta de novo uma vez, para que a falha do job sempre signifique um achado real, nunca uma cache corrompida.

As exceções vivem num arquivo próprio, cada uma com o motivo e uma data de expiração: passada a data, a vulnerabilidade volta a derrubar o job, então uma exceção nunca vira permanente sem alguém decidir de novo. As imagens que o k3s embute no próprio binário ficam de fora, porque não aparecem em nenhum manifesto do repositório e só mudam com a versão do k3s.

Os hooks de git versionados vivem junto das outras configurações de ferramenta, e uma recipe aponta o git para lá. O job de convenção de commit confere cada commit do push ou da pull request contra a mesma convenção do `CONTRIBUTING.md`: tipo permitido, título curto sem ponto final, sem corpo e sem rodapé. O hook correspondente, ligado pela mesma recipe, roda a mesma checagem antes de o commit existir.

O job de expiração de domínio consulta o registro do domínio do blog: num push só avisa quando o prazo está próximo, e na execução agendada falha quando está mais próximo ainda. Ele fica fora do gate pelo mesmo motivo do job de idade de segredo.

Um domínio vencido derruba de uma vez tudo o que está atrás dele, e a correção é uma renovação no registrador, não um deploy, então o aviso precisa chegar antes de a data virar falha.

O job de diff de manifesto roda só em pull request. Ele faz checkout da base e da cabeça do PR lado a lado, renderiza os charts em ambas e publica no resumo da execução o diff do que foi renderizado.

É o substituto de uma comparação direta contra o Argo na CI: essa comparação exigiria expor a API do Argo CD para a internet e guardar um token dele no GitHub, mesmo que só de leitura, e o servidor do Argo hoje só é alcançável pela rede local.

O diff renderizado não vê deriva do cluster, que a autocorreção já resolve, mas mostra exatamente o que o merge vai mandar o Argo aplicar. Ele fica fora do gate porque não reprova nada, só informa.

O job de idade de segredo fica fora do gate de propósito. Ele lê a data que o SOPS grava em texto claro em todo arquivo cifrado, sem precisar de chave, e compara com um prazo configurado. Num push ou pull request, um arquivo vencido só vira aviso na execução; na execução agendada diária o job falha, o workflow fica vermelho e o GitHub notifica por e-mail.

Assim um segredo vencido nunca bloqueia um deploy urgente, e também não passa semanas sem ninguém ver; veja [rotacionar credenciais](../operacional/rotacionar-credenciais.md) para o limite dessa medida.

O mesmo job também confere, com a mesma divisão entre aviso e falha, a data da última [revisão periódica](../operacional/revisao-periodica.md). Nenhuma recipe que decifra roda na CI, porque todas precisam da identidade da Secure Enclave; o job de segredos cifrados só confere, sem chave, que os arquivos continuam cifrados.

## Por que um workflow só

Um job separado para cada ferramenta exigiria uma entrada na branch protection para cada um deles, sem nenhum lugar único que respondesse à pergunta "este push está OK para mergear". Um workflow só, com um job de gate no final, resolve isso sem abrir mão de isolamento por job: cada job mantém sua própria permissão mínima, e o gate não precisa saber nada sobre o que cada ferramenta faz, só se alguma dependência falhou.

É esse único job que faz sentido marcar como obrigatório na branch protection, em vez da lista inteira, que cresce a cada gate novo.

## Nada entra sem digest ou checksum

Toda dependência que o repositório baixa tem uma identidade fixa no git, e o que não pode ter é dito aqui. Imagens de contêiner, nas aplicações do Argo, nos values das roles e no Dockerfile das ferramentas, vêm com [digest](../aprender/pinagem-por-digest-e-hash.md); o check de imagens pinadas recusa uma imagem só com tag, mesmo nos charts que o Ansible instala, porque a renderização os processa com os mesmos values da role. As referências de action dos workflows são SHA de commit.

A imagem do OpenTofu e a do actionlint levam digest, e o Renovate as acompanha por gerenciadores de regex que capturam versão e digest juntos.

As ferramentas instaladas dentro do Dockerfile não usam mais instalação por versão solta: cada uma tem um arquivo de dependências com hash obrigatório ou um lock file com integridade, e o Renovate atualiza esses arquivos pelos gerenciadores nativos. O `kubectl` e o plugin de Secure Enclave baixados na imagem de operação são conferidos contra um checksum, um publicado pelo projeto e outro fixado no Dockerfile.

A carência padrão que o Renovate espera antes de propor qualquer bump tem uma exceção deliberada: as imagens base rolantes do Dockerfile de ferramentas ficam sem essa carência, porque essas tags são republicadas com frequência e nunca acumulariam carência suficiente paradas; sem a exceção, essas imagens nunca seriam atualizadas de forma automática.

Do lado do node, o binário do k3s, o Helm e o cliente do Cilium sempre foram conferidos contra o checksum publicado. Passaram a ser também o script de instalação do k3s, baixado da tag e não do domínio de instalação genérico, e a chave apt do Tailscale, ambos contra um checksum fixado nas variáveis do Ansible.

Os charts do Argo CD e do Cilium entraram na mesma regra: o Ansible os puxa para o diretório de charts do node, confere contra o checksum declarado e só então renderiza, e a renderização repete a conferência na CI, então um bump de versão do Renovate sem o digest novo fica vermelho até alguém revisar o chart e atualizar o arquivo de versões.

O que fica sem hash tem motivo declarado. Os pacotes das distribuições são assinados pelo repositório da distribuição e fixados pela imagem base por digest ou pela release da Debian. A coleção do Ansible para tarefas POSIX vem do Galaxy só com versão, porque a ferramenta de coleção não confere checksum, e os índices dos repositórios Helm são consultados a cada pull, mas o que se instala dali é o arquivo conferido.

## Rodando localmente

Cada job tem uma receita correspondente no [justfile](https://github.com/guesant/hl-infrastructure/blob/main/justfile) que constrói a mesma imagem a partir de [.tools/docker/Dockerfile](https://github.com/guesant/hl-infrastructure/blob/main/.tools/docker/Dockerfile) e roda o mesmo comando; veja [rodar os quality gates localmente](../operacional/rodar-quality-gates-localmente.md). A recíproca não vale: o `justfile` também tem recipes que mudam o node ou o cluster de verdade, sem job de CI correspondente, porque não são coisa pra rodar a cada push, só quando o operador decide, à mão. Nenhuma delas pede senha, porque o inventário conecta como `root`; veja [rotacionar credenciais](../operacional/rotacionar-credenciais.md).

O OpenTofu é a exceção de imagem: todas as receitas dele usam direto a imagem oficial, porque essa imagem, ao contrário das demais, não pode virar um stage do Dockerfile compartilhado: desde uma versão recente ela recusa deliberadamente ser usada como base de outra imagem.

Só a receita de lint tem job correspondente na CI; as outras mexem em infraestrutura real fora do cluster e dependem de decifrar segredo com a identidade do operador, então ficam no mesmo grupo das recipes de bootstrap e rotação; as receitas de plano e apply em lote só repetem a receita simples em sequência para cada módulo, um de cada vez, cada apply confirmando por conta própria como sempre confirmou.

A receita que só lista os módulos existentes é a exceção: não toca em segredo nem em imagem nenhuma. A receita de passphrase do state, que gera ou rotaciona esse valor, também fica fora da CI: roda no host, como a sincronização de segredos. O mesmo vale para a checagem de placeholders, que precisa decifrar todo arquivo SOPS para saber o que ainda é valor de exemplo.

O `justfile` também carrega recipes que a CI nunca roda porque exigem a identidade do operador: as que aposentam o administrador temporário do Keycloak, criam usuários humanos nos realms e rotacionam a senha do administrador que o OpenTofu usa, falando só com a API do Keycloak pela tailnet; e as que rodam contra o próprio node por SSH, porque a API do k3s não é alcançável de nenhuma rede.

Elas ficam no mesmo arquivo para que a listagem de receitas seja o inventário completo do que se pode fazer com o repositório.

Outra categoria ainda não precisa nem de identidade nem de cluster: as duas recipes que só editam o arquivo de values de um chart local, o mesmo que [adicionar um satélite](../operacional/adicionar-um-satelite.md) descreve por extenso. Elas rodam dentro da imagem que já traz as ferramentas de manipulação de YAML, sem precisar de nenhum segredo, e ficam fora da CI pelo mesmo motivo das duas categorias anteriores: não têm o que verificar antes de existir um diff para revisar.

A ferramenta de estatística de prosa fica fora do check por um motivo do lado oposto: mede sentenças, palavras e crases por parágrafo, e diagramas mermaid por página, para achar onde a prosa fragmentou, inchou ou saturou de crase, mas as próprias réguas de [convenções de escrita](../contribuindo/convencoes-de-escrita.md) que ela testa já assumem que uma página antiga só se ajusta quando alguém mexe nela por outro motivo, não como consequência automática de um gate novo.

As ferramentas de lint de prosa e de gramática seguem o mesmo raciocínio com Vale e LanguageTool: contra as páginas já publicadas, ainda geram falso positivo demais para virar gate sem antes calibrar regra e vocabulário contra o volume real de conteúdo.

O cspell foi o gate de ortografia até esta decisão; ele saiu do check e do job de ortografia da CI porque essa responsabilidade passou para o LanguageTool, junto com a gramática que o cspell nunca cobriu.

A transição custou o vocabulário técnico que o cspell trazia pronto por dicionários de terceiros: [.tools/languagetool-pt-extra-words.txt](https://github.com/guesant/hl-infrastructure/blob/main/.tools/languagetool-pt-extra-words.txt) nasceu extraindo esses mesmos dicionários uma vez, e cresce dali em diante por curadoria manual, o mesmo jeito que o dicionário do cspell crescia, só que mirando um arquivo com formato mais simples, uma palavra por linha. Durante a transição para o LanguageTool virar gate, não existe checagem de ortografia obrigatória: o custo aceito por trocar de ferramenta.

## Continue por aqui

[Rodar os quality gates localmente](../operacional/rodar-quality-gates-localmente.md) mostra como reproduzir qualquer um destes jobs no próprio Mac antes de dar push.
