# Categorização e organização

Esta página é a fonte canônica de duas perguntas que antes viviam espalhadas, sem endereço próprio: qual conteúdo pertence a qual seção, e como cada seção se organiza fisicamente por dentro. Antes, o critério de categorização estava fragmentado entre um parágrafo em [Contribuindo](index.md) e a segunda metade de [Diátaxis](../aprender/diataxis.md); essa segunda metade só fazia sentido para quem já conhecia este repositório, o que contradizia a própria regra de que uma página de [Aprender](../aprender/index.md) deve fazer sentido para qualquer pessoa de fora dele. Ela foi movida para cá.

## As quatro seções e o que cada uma responde

O critério de categorização não é o assunto de uma página, é o propósito comunicativo dela: se o leitor terminar a página, ele entendeu um conceito, resolveu uma tarefa concreta, entendeu por que este repositório decidiu algo, ou consultou um fato rapidamente. Cada um desses quatro propósitos tem uma seção própria, e uma página deve caber claramente numa só.

**Aprender** explica conceito e ferramenta, sem depender de nenhuma decisão deste repositório. Uma página aqui deve continuar fazendo sentido para alguém que nunca ouviu falar do hl-infrastructure; ela pode citar um exemplo deste cluster, mas o argumento não pode depender de conhecê-lo. Nenhuma página de Aprender tem uma sequência de passos a executar, e essa ausência é uma decisão, não uma lacuna: esta documentação não reserva uma seção separada para lição prática guiada, porque o público real é quem opera este cluster, não quem está estudando um caminho alternativo; Aprender permanece puramente explicativo.

**Arquitetura** argumenta a escolha deste repositório especificamente. O que a distingue de Aprender é que ela assume que o leitor já sabe o que é a ferramenta em questão, e assume que o leitor quer saber por que ela foi usada deste jeito e não de outro, com as alternativas descartadas e o custo de cada decisão.

**Operacional** é o how-to da implementação real e já decidida deste repositório. Cada página resolve uma tarefa concreta que quem já opera o cluster precisa fazer, sem reexplicar conceito nenhum; se uma explicação for necessária, ela linka para Aprender ou Arquitetura em vez de repeti-la. Uma página aqui pode ser tão guiada e sequencial quanto um passo a passo didático, como é o caso de [Primeiro bootstrap](../operacional/primeiro-bootstrap.md); o que a distingue de uma lição é que ela produz o cluster de produção real que o operador vai de fato manter, não um exercício descartável.

**Referência** cobre sintaxe de comando de ferramenta genérica e catálogos externos, deliberadamente mais estreita do que a definição original de reference material. Nomes de variável, valor de configuração e esquema de recurso deste repositório especificamente não entram aqui, porque já vivem no código, que é a fonte de verdade; duplicá-los em prosa criaria uma segunda cópia para manter sincronizada, e uma cópia desatualizada é pior do que a ausência dela, porque continua parecendo confiável.

## Relação com o Diátaxis

O [Diátaxis](https://diataxis.fr/) é um framework de organização de documentação técnica, criado por Daniele Procida, que separa conteúdo em tutorial, how-to guide, reference e explanation, pela necessidade de quem lê em vez do assunto. As quatro seções deste repositório não são os quadrantes do Diátaxis original, mas adaptam a mesma separação, com divergências deliberadas que valem registrar explicitamente para não sugerir uma conformidade que não existe.

Aprender corresponde a explanation. Arquitetura também deriva de explanation, mas diverge da versão original do framework, que descreve explanation como algo removido do trabalho ativo; aqui ela é argumentativa e amarrada à decisão real do produto, porque é exatamente esse argumento que o leitor de Arquitetura busca. Operacional corresponde a how-to guide. Referência corresponde a reference, mas mais estreita que a definição original, que estrutura reference ao redor do próprio produto; aqui, fatos deste produto específico ficam de fora de propósito, pela mesma razão de fonte única de verdade já explicada acima.

O quadrante tutorial não tem seção própria aqui, de propósito: ele pressupõe um leitor estudando um caminho alternativo, num ambiente descartável, e o público real desta documentação é quem já opera este cluster específico. Um exercício prático desse tipo, se algum dia valer a pena escrever, cabe como uma subseção de Aprender, não como uma seção de topo à espera de conteúdo.

## Quando criar uma seção, uma página, ou dividir uma existente

Uma seção nova só se justifica quando ela responde a um propósito comunicativo que nenhuma das quatro seções atuais cobre, e quando já existe conteúdo real para publicar nela, não apenas a expectativa de que ele venha a existir. Uma página nova nasce quando um conceito, uma decisão ou uma tarefa ainda não tem endereço nenhum; ela deve caber claramente numa seção, e se o conteúdo pretendido mistura como fazer com por que funciona, o sinal é que ele deveria virar duas páginas separadas, uma em cada seção, ligadas uma à outra pela seção final de cada uma. Uma página existente deve ser dividida quando ela cresce a ponto de misturar dois propósitos comunicativos distintos sob o mesmo título, ou quando um heading dentro dela passa a cobrir um assunto independente o bastante para merecer sua própria página; o teste é o mesmo, um heading que não cabe no assunto do título da página é sinal de que a página, não o parágrafo, precisa ser reorganizada. Duas páginas devem ser fundidas quando cobrem o mesmo propósito comunicativo para o mesmo conceito, e a separação entre elas existe só por acidente histórico, não por uma distinção real de audiência ou de finalidade.

Uma página de índice de seção cumpre duas funções ao mesmo tempo, hoje sem conflito entre elas: ela é a porta de entrada em prosa, com sua própria ordem de leitura sequencial e didática, e é também o primeiro item listado na navegação da seção. As duas coisas podem usar agrupamentos diferentes, como a próxima seção desta página explica, porque servem propósitos diferentes: ler em sequência e navegar por busca rápida.

## Um conceito, uma página

Uma página de Aprender trata de uma unidade de conhecimento por vez. Relação entre assuntos não é motivo suficiente para fundi-los. Se dois conceitos, abordagens ou produtos possuem definição, mecanismo, limitações, alternativas ou fontes próprias, cada um merece endereço próprio.

A profundidade não é medida pelo tamanho da página. Uma página pode ser longa quando aprofunda uma única unidade. O problema é largura temática: uma página sobre SAST pode aprofundar análise sintática, semântica, fluxo de dados, taint analysis, falsos positivos e integração no ciclo de desenvolvimento; ela não deve virar, ao mesmo tempo, o manual de CodeQL, Semgrep e SonarQube.

Quando várias implementações pertencem à mesma categoria, use três tipos de página:

1. uma página de categoria ou abordagem, que explica o espaço do problema e relaciona as implementações;
2. uma página própria para cada implementação relevante;
3. uma página de comparação quando houver diferenças suficientes para justificar uma análise lado a lado.

A comparação não repete as páginas individuais. Ela explicita dimensões comparáveis, trade-offs, sobreposições, diferenças e critérios de decisão e aponta para os documentos especializados.

A regra se aplica também ao conteúdo já publicado. Uma revisão dedicada de estrutura pode promover headings independentes a páginas próprias e transformar a página original numa página de categoria, comparação ou mapa.

### O que significa aprofundar

Uma página de conceito, abordagem ou ferramenta deve, quando aplicável, responder às perguntas abaixo. Os headings não precisam ser idênticos nem aparecer mecanicamente quando não fizerem sentido.

- O que é?
- O que não é e quais são suas fronteiras?
- Qual problema motivou sua existência?
- Como funciona internamente?
- Quais abstrações e componentes formam o modelo?
- Em quais casos de uso é apropriado?
- Em quais casos não é apropriado?
- Como aparece em sistemas reais?
- Qual é um exemplo mínimo que demonstra o mecanismo?
- Qual é um exemplo realista de produção?
- Quais são as boas práticas?
- Quais são as más práticas e anti-patterns?
- Quais falhas e erros de entendimento são comuns?
- Quais são seus limites e trade-offs?
- Quais implicações de segurança, desempenho e operação existem?
- Quais alternativas existem, gratuitas, abertas, comerciais ou gerenciadas?
- Como organizações e ambientes enterprise costumam aplicar o conceito?
- Quais padrões, especificações, RFCs, documentação oficial ou outras fontes primárias sustentam a explicação?

Exemplo não é sinônimo de tutorial. Em Aprender, exemplos existem para tornar um mecanismo observável e concreto. Uma sequência destinada a alterar o cluster real continua pertencendo a Operacional.

Boas práticas também precisam de fundamentação. Evite regras apresentadas como universais quando dependem de contexto. Explique qual risco a prática reduz, quais premissas ela assume e quando a recomendação deixa de fazer sentido. Da mesma forma, uma má prática deve mostrar o modo de falha, e não apenas receber o rótulo de "errada".

### Páginas de categoria e páginas-mapa

Descompactar não significa criar índices vazios. Uma página de categoria explica o mapa conceitual daquele espaço: vocabulário, fronteiras, relações, dimensões de comparação e quando seguir para cada filho.

Por exemplo, uma página de segurança de aplicações pode situar SAST, DAST, SCA e secret scanning sem tentar ensinar profundamente cada técnica. Cada técnica recebe a própria página. Uma página de SAST, por sua vez, pode apontar para CodeQL e outras implementações sem absorver a documentação de cada produto.

Esse padrão permite que o leitor pare no nível de abstração de que precisa: domínio, categoria, abordagem ou implementação.

## Hierarquia de navegação

A navegação lateral representa a taxonomia do conhecimento, não apenas uma lista de arquivos. A hierarquia pode seguir, quando fizer sentido:

`seção → domínio → categoria → abordagem/conceito → ferramenta ou implementação`.

A profundidade não possui um limite artificial de níveis. Um caminho como `Aprender → Segurança → Segurança de aplicações → SAST → CodeQL` é aceitável porque cada nível responde a uma pergunta classificatória diferente. O problema a evitar é nesting sem significado ou categorias que existam apenas para reduzir o número de itens visíveis.

Páginas intermediárias devem ser úteis por si mesmas. Um grupo que representa um conceito real deve preferencialmente possuir uma página-mapa correspondente, em vez de existir somente como rótulo da sidebar.

O filesystem deve acompanhar a taxonomia quando isso tornar a classificação mais previsível. Uma árvore como `aprender/seguranca/appsec/sast/codeql.md` comunica mais do que dezenas de arquivos não relacionados no mesmo diretório. A navegação não precisa reproduzir mecanicamente cada diretório, mas caminho, sidebar e modelo conceitual não devem contradizer uns aos outros.

A ordem dentro de cada categoria segue dependência conceitual: primeiro fundamentos, depois abordagens, implementações, comparações e assuntos avançados. O índice de Aprender continua oferecendo uma trilha em prosa; a sidebar serve principalmente à descoberta e à localização rápida.

## Continue por aqui

[Convenções de escrita](convencoes-de-escrita.md) cobre a mecânica de como uma página, já classificada pelo critério desta página, deve ser escrita por dentro.
