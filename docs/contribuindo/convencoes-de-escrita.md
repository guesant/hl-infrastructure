# Convenções de escrita

Estas convenções valem para toda página desta documentação.

Escreva em prosa corrida, em parágrafos que desenvolvem uma ideia até o fim antes de passar para a próxima. Uma lista só se justifica quando o conteúdo é de fato uma coleção de itens independentes ou uma sequência de comandos a executar em ordem; não transforme uma explicação contínua numa lista só porque listas são mais fáceis de escrever.

Não use travessão, meia-risca ou setas Unicode. Escreva a relação em palavras, com uma vírgula, um ponto e vírgula, ou uma frase nova.

Todo termo técnico introduzido pela primeira vez numa página deve ter contexto suficiente para ser entendido sem sair da página; um link para a seção de arquitetura correspondente conta como contexto suficiente quando a explicação completa já existe lá. Linke um termo técnico toda vez que ele aparecer no texto, mesmo quando já foi linkado antes na mesma página; ao contrário da convenção comum de linkar só a primeira menção, aqui repetir o link custa pouco e poupa quem chegou a esse ponto da página por uma âncora ou por busca, sem ter lido o parágrafo anterior.

Toda página deve terminar com uma seção "Continue por aqui" com links para onde faz sentido ir a seguir. Isso vale para toda página sem exceção, incluindo uma que pareça uma folha sem continuação óbvia; nesse caso, o link vai para a página que motivou a criação desta, ou para o índice da seção.

Nomes de arquivo devem ser em minúsculo, com hífen, sem acento.

## Parágrafos

O limite de um parágrafo é semântico, não visual. Um parágrafo deve sustentar uma ideia central reconhecível e desenvolvê-la até o ponto em que a informação seguinte representa uma mudança de foco: quando o texto deixa de explicar um mecanismo e passa a tratar da consequência dele, de uma exceção relevante, de uma decisão diferente ou de outro componente, ali existe uma divisão natural, e ela deveria virar um parágrafo novo. O contrário também vale: um raciocínio contínuo não deve ser cortado só porque o bloco ficou grande na tela.

Ambos os extremos são erros. Uma sequência de parágrafos de uma frase transforma a explicação em telegrama e obriga quem lê a reconstruir as ligações que o texto deixou de fazer. Um bloco que acumula vários componentes, vários nomes de recurso e várias exceções exige que o leitor mantenha tudo isso na memória ao mesmo tempo, e a informação do meio se perde. Uma pista prática de que um parágrafo passou do limite é ele precisar de mais de um "por isso" ou "além disso" para amarrar assuntos que não dependem uns dos outros; nesse caso, cada assunto ganha o seu parágrafo, e o que sobrar de ligação entre eles cabe numa frase de transição. Aprender, arquitetura e operacional têm ritmos diferentes por natureza, e uma página conceitual pode desenvolver mais do que um runbook; a régua é a mesma, o tamanho resultante não.

## Frases e cadência

Uma frase pode ser longa quando as partes dependem umas das outras, mas uma frase que acumula orações subordinadas, parênteses, enumerações e exceções deveria ser examinada: em geral frases separadas explicam melhor sem fragmentar a prosa. Um parêntese só se justifica quando o aparte é curto e não muda o argumento; se ele carrega uma condição, um nome de arquivo e uma exceção, ele é uma frase disfarçada.

Estruturas individualmente corretas se tornam um problema quando se repetem até denunciar um molde. Não force todo parágrafo a seguir a mesma fórmula de afirmação, explicação, consequência e conclusão. Não abra sistematicamente com uma frase que anuncia o que o parágrafo vai fazer, nem feche reafirmando em outras palavras o que acabou de ser dito. Não crie por hábito uma frase introdutória seguida de dois-pontos e uma enumeração, nem repita a construção "não é X, é Y" a cada contraste. A variedade não deve ser fabricada; ela surge sozinha quando a estrutura de cada parágrafo vem do raciocínio que ele expõe, e não de um esqueleto preenchido.

Evite linguagem hedgeada, que soa cautelosa mas não diz nada. Se uma afirmação é verdadeira, escreva-a como afirmação; se ela tem uma condição ou uma exceção, nomeie a condição ou a exceção em vez de escondê-la num advérbio de cautela.

## Crases, code blocks e ênfase

Reserve crases para o que é literalmente um comando, um caminho de arquivo, um nome de variável ou outro identificador técnico exato. Não use crase como forma de destaque visual para um termo qualquer que pareça técnico.

Mesmo quando cada crase individual está correta, um parágrafo com um identificador marcado a cada poucas palavras cansa a leitura e passa a parecer uma descrição do código em vez de documentação. A regra não é usar menos crases, é não deixar a representação literal dominar a frase. Antes de remover uma crase de um identificador que precisa ser literal, veja se a frase está citando detalhe demais: muitas vezes dá para nomear o conceito em prosa e deixar só o identificador que importa para o argumento, mover um conjunto de valores para uma tabela, apresentar uma estrutura num code block, ou cortar a repetição de um nome que o contexto já tornou óbvio. Um code block continua sendo a forma certa de mostrar um comando, uma configuração ou um exemplo que precisa ser copiado ou lido como código.

Negrito e itálico não deveriam ser usados como decoração. Negrito cabe em um termo que está sendo definido naquele momento ou num aviso que precisa saltar aos olhos; itálico, em uma palavra estrangeira ou num uso metalinguístico. Um parágrafo com vários trechos em negrito não tem nada destacado.

## Títulos e organização

Um heading deve representar uma divisão real do assunto e ajudar alguém a navegar pela página. Não crie uma subseção porque surgiu um parágrafo novo, nem deixe uma seção crescer até discutir vários assuntos independentes sob um título que só descreve o primeiro deles. Um conteúdo que não cabe em nenhum heading da página é sinal de que a página, e não o parágrafo, precisa ser reorganizada.

## Vocabulário de obrigatoriedade

Estas convenções usam deve, deveria e pode com o mesmo peso que a RFC 2119 dá a esses termos numa especificação técnica. Deve marca uma regra sem exceção, cuja violação é um erro a corrigir onde for encontrado. Deveria marca uma prática recomendada, com exceção possível quando há um motivo concreto e melhor documentado que ela naquele lugar específico. Pode marca uma opção livre, deixada ao critério de quem escreve. Uma convenção nova, ao ser adicionada aqui, ganha um desses verbos explicitamente, para não deixar a régua de rigor implícita.

## Continue por aqui

[Normas de redação técnica](normas-de-redacao-tecnica.md) explica a origem dessas convenções; [voz e tom](voz-e-tom.md) mostra o estilo em ação, com exemplos de antes e depois.
