# Convenções de escrita

Estas convenções valem para toda página desta documentação.

Escreva em prosa corrida, em parágrafos que desenvolvem uma ideia até o fim antes de passar para a próxima. Uma lista só se justifica quando o conteúdo é de fato uma coleção de itens independentes ou uma sequência de comandos a executar em ordem; não transforme uma explicação contínua numa lista só porque listas são mais fáceis de escrever.

Não use travessão, meia-risca ou setas Unicode. Escreva a relação em palavras, com uma vírgula, um ponto e vírgula, ou uma frase nova.

Todo termo técnico introduzido pela primeira vez numa página deve ter contexto suficiente para ser entendido sem sair da página; um link para a seção de arquitetura correspondente conta como contexto suficiente quando a explicação completa já existe lá. Linke um termo técnico toda vez que ele aparecer no texto, mesmo quando já foi linkado antes na mesma página; ao contrário da convenção comum de linkar só a primeira menção, aqui repetir o link custa pouco e poupa quem chegou a esse ponto da página por uma âncora ou por busca, sem ter lido o parágrafo anterior.

Toda página deve terminar com uma seção "Continue por aqui" com links para onde faz sentido ir a seguir. Isso vale para toda página sem exceção, incluindo uma que pareça uma folha sem continuação óbvia; nesse caso, o link vai para a página que motivou a criação desta, ou para o índice da seção.

Nomes de arquivo devem ser em minúsculo, com hífen, sem acento.

## Parágrafos

Um parágrafo deve ter entre três e cinco frases. Essa é uma régua numérica, não uma sugestão: o motivo de existir é que texto escrito com assistência de modelo de linguagem tende a dois defeitos opostos e recorrentes, o parágrafo telegráfico de uma frase só e o parágrafo que acumula assunto demais, e um número mínimo e máximo é o jeito de pegar os dois sem depender só de julgamento a cada página.

Um parágrafo com seis frases ou mais deve ser dividido. O ponto de corte é a mudança de foco mais próxima do meio, quando o texto deixa de explicar um mecanismo e passa a tratar da consequência dele, de uma exceção, de uma decisão diferente ou de outro componente; quando o parágrafo é de fato um raciocínio só, sem nenhuma divisão temática real, o corte fica no ponto onde a explicação do mecanismo termina e a ilustração ou a consequência dele começa. Um parágrafo grande sem divisão nenhuma disponível é a exceção rara, não a saída padrão, e deveria ser raro o bastante para chamar atenção quando aparece.

Um parágrafo com duas frases ou menos deve ser desenvolvido até ter começo, meio e fim: a afirmação central, o que ela implica ou de onde ela vem, e o que ela custa ou o que ela evita. Uma frase solta que só constata um fato, sem abrir o "e daí" dele, é parágrafo incompleto, não parágrafo enxuto. A exceção rara aqui é a frase de transição entre seções, o fecho de "Continue por aqui" e a linha que introduz um code block ou uma tabela, porque esses não carregam argumento próprio.

Aprender, arquitetura e operacional têm ritmos diferentes por natureza, e uma página conceitual pode preferir o topo da faixa enquanto um runbook fica perto do piso; a faixa de três a cinco frases vale para as duas, o que muda é onde dentro dela cada seção tende a cair.

## Frases e cadência

Uma frase pode ser longa quando as partes dependem umas das outras, mas uma frase que acumula orações subordinadas, parênteses, enumerações e exceções deveria ser examinada: em geral frases separadas explicam melhor sem fragmentar a prosa. Um parêntese só se justifica quando o aparte é curto e não muda o argumento; se ele carrega uma condição, um nome de arquivo e uma exceção, ele é uma frase disfarçada.

Estruturas individualmente corretas se tornam um problema quando se repetem até denunciar um molde. Não force todo parágrafo a seguir a mesma fórmula de afirmação, explicação, consequência e conclusão. Não abra sistematicamente com uma frase que anuncia o que o parágrafo vai fazer, nem feche reafirmando em outras palavras o que acabou de ser dito. Não crie por hábito uma frase introdutória seguida de dois-pontos e uma enumeração, nem repita a construção "não é X, é Y" a cada contraste. A variedade não deve ser fabricada; ela surge sozinha quando a estrutura de cada parágrafo vem do raciocínio que ele expõe, e não de um esqueleto preenchido.

Evite linguagem hedgeada, que soa cautelosa mas não diz nada. Se uma afirmação é verdadeira, escreva-a como afirmação; se ela tem uma condição ou uma exceção, nomeie a condição ou a exceção em vez de escondê-la num advérbio de cautela.

## Crases, code blocks e ênfase

Reserve crases para o que é literalmente um comando, um caminho de arquivo, um nome de variável ou outro identificador técnico exato. Não use crase como forma de destaque visual para um termo qualquer que pareça técnico.

Mesmo quando cada crase individual está correta, um parágrafo com um identificador marcado a cada poucas palavras cansa a leitura e passa a parecer uma descrição do código em vez de documentação. A regra não é usar menos crases, é não deixar a representação literal dominar a frase. Antes de remover uma crase de um identificador que precisa ser literal, veja se a frase está citando detalhe demais: muitas vezes dá para nomear o conceito em prosa e deixar só o identificador que importa para o argumento, mover um conjunto de valores para uma tabela, apresentar uma estrutura num code block, ou cortar a repetição de um nome que o contexto já tornou óbvio. Um code block continua sendo a forma certa de mostrar um comando, uma configuração ou um exemplo que precisa ser copiado ou lido como código.

Existe uma distinção firme entre duas coisas que a crase cobre hoje, e vale separá-las. A primeira é o literal que precisa bater exatamente com o que está no disco ou na tela: um comando, um caminho, um nome de campo de manifesto, uma flag, uma variável de ambiente, o valor exato de um `kind:` ou de um nome de recurso. Esse uso deve manter a crase sempre. A segunda é o nome de um tipo de recurso usado como substantivo comum dentro do raciocínio da frase, como `Gateway`, `HTTPRoute` ou `Secret` citados de novo e de novo só para dizer "o gateway faz isso" ou "a rota aceita aquilo". Depois da primeira menção de um tipo de recurso numa seção, as menções seguintes devem virar prosa sem crase ("o gateway", "a rota", "o segredo"), reservando a crase para o momento em que a frase de fato cita o objeto por nome exato (`Secret` `internal-domain-tls`) ou o campo do manifesto que o declara. Um parágrafo em que o mesmo nome de tipo aparece com crase três vezes ou mais é sinal de que a segunda categoria está sendo tratada como a primeira.

Negrito e itálico não deveriam ser usados como decoração. Negrito cabe em um termo que está sendo definido naquele momento ou num aviso que precisa saltar aos olhos; itálico, em uma palavra estrangeira ou num uso metalinguístico. Um parágrafo com vários trechos em negrito não tem nada destacado.

## Títulos e organização

Um heading deve representar uma divisão real do assunto e ajudar alguém a navegar pela página. Não crie uma subseção porque surgiu um parágrafo novo, nem deixe uma seção crescer até discutir vários assuntos independentes sob um título que só descreve o primeiro deles. Um conteúdo que não cabe em nenhum heading da página é sinal de que a página, e não o parágrafo, precisa ser reorganizada.

## Vocabulário de obrigatoriedade

Estas convenções usam deve, deveria e pode com o mesmo peso que a RFC 2119 dá a esses termos numa especificação técnica. Deve marca uma regra sem exceção, cuja violação é um erro a corrigir onde for encontrado. Deveria marca uma prática recomendada, com exceção possível quando há um motivo concreto e melhor documentado que ela naquele lugar específico. Pode marca uma opção livre, deixada ao critério de quem escreve. Uma convenção nova, ao ser adicionada aqui, ganha um desses verbos explicitamente, para não deixar a régua de rigor implícita.

## Continue por aqui

[Normas de redação técnica](normas-de-redacao-tecnica.md) explica a origem dessas convenções; [voz e tom](voz-e-tom.md) mostra o estilo em ação, com exemplos de antes e depois.
