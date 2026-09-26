# Livros e referências de matemática, computação e engenharia de software

Esta página reúne livros, cursos, catálogos de padrões e fontes primárias para estudar matemática, ciência da computação, algoritmos, estruturas de dados, bancos de dados, engenharia de software e system design. Ela é um catálogo de referência, não uma lista de leituras obrigatórias nem uma substituição para a documentação das ferramentas.

Para escolher um recurso, observe o problema que ele resolve, a edição, a data de atualização, as erratas e a relação entre teoria e prática. Um livro pode continuar sendo uma boa referência conceitual mesmo quando a ferramenta descrita mudou, mas exemplos de APIs, bibliotecas e serviços precisam ser conferidos na fonte oficial atual.

## Martin Fowler e catálogos de padrões

[Martin Fowler](https://martinfowler.com/) mantém artigos, livros e catálogos sobre refatoração, arquitetura de aplicações, padrões de integração e práticas de engenharia de software. O material é especialmente útil para conectar decisões de implementação a modelos que podem ser comparados entre projetos.

- [Livros de Martin Fowler](https://martinfowler.com/books/): catálogo oficial com as obras e os temas de cada uma.
- [Refactoring](https://www.martinfowler.com/books/refactoring.html): referência para melhorar o desenho interno do código preservando seu comportamento observável.
- [Patterns of Enterprise Application Architecture](https://www.martinfowler.com/books/eaa.html): padrões para organizar aplicações corporativas, acesso a dados, domínio, apresentação e transações.
- [Catalog of Patterns of Enterprise Application Architecture](https://www.martinfowler.com/eaaCatalog/index.html): catálogo consultável dos padrões do livro.

O catálogo de Fowler deve ser usado para nomear e comparar formas de composição, não como uma autorização para aplicar um padrão fora do problema que o motivou. A descrição do padrão ajuda a reconhecer forças e consequências; a decisão sobre adotá-lo continua pertencendo ao contexto da aplicação.

[Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/) é o catálogo de Gregor Hohpe e Bobby Woolf para integração entre aplicações. O site apresenta um vocabulário de padrões independente de fornecedor, com foco em mensagens, canais, roteamento, transformação, endpoints, sistemas de mensageria e composição de fluxos.

- [Messaging patterns](https://www.enterpriseintegrationpatterns.com/patterns/messaging/): entrada para canais, mensagens, endpoints, roteadores e transformadores.
- [Message patterns](https://www.enterpriseintegrationpatterns.com/patterns/messaging/Messaging.html): catálogo de padrões de mensagens e suas relações.
- [Enterprise Integration Patterns, livro](https://www.enterpriseintegrationpatterns.com/books/): referência principal do catálogo e de sua organização conceitual.

O catálogo é particularmente útil quando uma arquitetura precisa distinguir, por exemplo, uma fila de um canal, um evento de um comando, roteamento de transformação ou entrega assíncrona de uma chamada RPC. As páginas de [filas](../aprender/dados/mensageria/filas.md), [streaming de eventos](../aprender/dados/mensageria/event-streaming.md), [outbox](../aprender/dados/mensageria/outbox.md) e [jobs e workers](../aprender/dados/mensageria/jobs-e-workers.md) tratam essas ideias no contexto dos mecanismos documentados neste repositório.

## Matemática para ciência da computação

Matemática discreta dá a linguagem para raciocinar sobre programas, algoritmos, redes, criptografia e sistemas distribuídos. O objetivo não é acumular técnicas isoladas, mas aprender a modelar objetos, declarar hipóteses, provar propriedades e identificar os casos em que uma conclusão não se aplica.

- [MIT 6.042J, Mathematics for Computer Science](https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-spring-2015/): lógica, provas, indução, conjuntos, relações, grafos, contagem, probabilidade e matemática discreta aplicada à computação.
- [Notas de aula do MIT 6.042J](https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-fall-2005/pages/lecture-notes/): material de consulta para revisar demonstrações e definições.
- [MIT 18.06SC, Linear Algebra](https://ocw.mit.edu/courses/18-06sc-linear-algebra-fall-2011/): vetores, matrizes, transformações lineares, espaços vetoriais, autovalores e decomposições.
- [MIT 18.404J, Theory of Computation](https://ocw.mit.edu/courses/18-404j-theory-of-computation-fall-2020/pages/syllabus/): linguagens formais, autômatos, computabilidade e limites do que pode ser calculado.

Esses recursos se complementam. A matemática discreta sustenta provas e estruturas combinatórias; álgebra linear aparece em computação científica, gráficos, otimização e aprendizado de máquina; teoria da computação estabelece limites para problemas e modelos de execução. Em todos os casos, vale separar definição, hipótese, algoritmo e prova de correção.

## Fundamentos de ciência da computação e sistemas

- [Operating Systems: Three Easy Pieces](https://pages.cs.wisc.edu/~remzi/OSTEP/): livro aberto sobre virtualização, concorrência, persistência e os mecanismos que formam um sistema operacional.
- [Computer Systems: A Programmer's Perspective](https://csapp.cs.cmu.edu/3e/perspective.html): relação entre código, compilação, representação de dados, arquitetura, memória, linking, concorrência e rede.
- [MIT OpenCourseWare](https://ocw.mit.edu/search/?d=Electrical%20Engineering%20and%20Computer%20Science): catálogo amplo de cursos de engenharia elétrica e ciência da computação.
- [ACM Digital Library](https://dl.acm.org/): artigos, conferências e literatura de computação publicados ou indexados pela ACM.
- [USENIX Publications](https://www.usenix.org/publications): trabalhos e conferências sobre sistemas, segurança, operação e desempenho.

As páginas de [namespaces e usuários](../aprender/sistemas/linux/namespaces.md), [systemd](../aprender/sistemas/systemd/unit.md), [containers](../aprender/containers/index.md) e [sistemas distribuídos](../aprender/arquitetura-aplicacoes/sistemas-distribuidos.md) aprofundam partes desse fundamento com foco nos mecanismos e tecnologias relevantes ao ambiente.

## Algoritmos

Algoritmos devem ser estudados junto com modelos de custo, invariantes e estruturas de dados. A mesma ideia pode ter comportamentos muito diferentes em memória, disco, rede ou execução concorrente, por isso a análise assintótica é uma ferramenta de comparação, não uma previsão completa do tempo de resposta em produção.

- [Algoritmos e estruturas de dados](../aprender/engenharia-software/algoritmos-e-estruturas-de-dados.md): mapa das famílias de estruturas e algoritmos e dos critérios de escolha.
- [Análise de complexidade](../aprender/engenharia-software/analise-de-complexidade.md): Big O, melhor caso, pior caso, caso médio e análise amortizada.
- [Arrays fixos e dinâmicos](../aprender/engenharia-software/arrays-fixos-e-dinamicos.md): localidade, capacidade, realocação e crescimento geométrico.
- [Introduction to Algorithms, 4th edition](https://mitpress.mit.edu/9780262046305/introduction-to-algorithms/): referência abrangente sobre algoritmos, análise, grafos, otimização, estruturas de dados e algoritmos avançados.
- [Algorithms, 4th edition, Princeton](https://algs4.cs.princeton.edu/home/): livro e material didático com implementações, visualizações, exercícios e análise de algoritmos fundamentais.
- [The Algorithm Design Manual](https://www.algorist.com/): abordagem orientada à modelagem do problema, escolha de estratégias e reconhecimento de famílias de algoritmos.
- [MIT 6.006, Introduction to Algorithms](https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-fall-2011/): curso com aulas, problemas e implementação de algoritmos e estruturas de dados.
- [Algorithms + Data Structures = Programs, Niklaus Wirth](https://people.inf.ethz.ch/~wirth/AD.pdf): edição digital disponibilizada pelo autor, publicada originalmente em 1976.

Uma sequência prática é começar por análise de complexidade, indução e invariantes; seguir para vetores, listas, pilhas, filas, tabelas de dispersão, árvores e heaps; depois estudar ordenação, busca, grafos, programação dinâmica, algoritmos gulosos e aleatorização. A implementação deve ser acompanhada de testes de fronteira e de uma explicação do motivo pelo qual o algoritmo é correto.

## Estruturas de dados

Estruturas de dados são formas de organizar estado para tornar determinadas operações baratas ou previsíveis. A escolha precisa declarar quais operações são prioritárias, como os dados são acessados, se a memória é limitada, se há persistência e se múltiplos processos podem modificar o estado.

- [Princeton Algorithms, seção de fundamentos](https://algs4.cs.princeton.edu/13stacks/): pilhas, filas, listas, análise de custo e abstrações de coleções.
- [Princeton Algorithms, árvores e tabelas de símbolos](https://algs4.cs.princeton.edu/32bst/): árvores de busca, tabelas ordenadas e estruturas balanceadas.
- [MIT 6.006](https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-fall-2011/): estruturas de dados apresentadas junto com os algoritmos que as utilizam.
- [CS:APP](https://csapp.cs.cmu.edu/3e/perspective.html): representação de dados, memória e efeitos da arquitetura que influenciam a implementação.
- [Amortized analysis](https://en.wikipedia.org/wiki/Amortized_analysis): referência introdutória para custo de sequências de operações.
- [Discussão sobre o crescimento de arrays dinâmicos](https://stackoverflow.com/questions/1100311/what-is-the-ideal-growth-rate-for-a-dynamically-allocated-array): comparação de fatores de crescimento e seus trade-offs.
- [Optimal memory reallocation and the golden ratio, arquivo](https://web.archive.org/web/20170808090051/https://crntaylor.wordpress.com/2011/07/15/optimal-memory-reallocation-and-the-golden-ratio/): análise histórica da relação entre realocação, capacidade excedente e reutilização de memória.
- [CPython 2.6, `listobject.c`](https://github.com/python/cpython/blob/2.6/Objects/listobject.c#L41): exemplo histórico de uma política de sobrealocação de listas.

Para sistemas reais, relacione cada estrutura à sua contraparte persistente ou distribuída. Uma tabela de dispersão em memória, um índice B-tree em um banco e um log particionado resolvem problemas diferentes, embora todos organizem dados para facilitar uma forma de consulta. A comparação correta começa pelas operações e pelas garantias necessárias, não pelo nome da estrutura.

## Aprender e pesquisar

- [Aprender, pesquisar e perguntar](../aprender/educacao-pesquisa/aprender-e-pesquisar.md): objetivos observáveis, recuperação, fontes primárias, reprodução e perguntas técnicas.
- [The Art of Doing Science and Engineering: Learning to Learn, Richard Hamming](https://savage.nps.edu/hamming/HammingLearningToLearnRecovered/chapters/Hamming01.pdf): reflexão sobre aprendizagem, investigação e escolha de problemas.

## Bancos de dados e sistemas de dados

- [CMU 15-445/645, Database Systems](https://15445.courses.cs.cmu.edu/spring2025/syllabus.html): armazenamento, buffer pool, índices, processamento de consultas, transações, concorrência e recuperação.
- [CMU Database Group, courses](https://db.cs.cmu.edu/courses/): cursos, laboratórios e sistemas de banco de dados mantidos pelo grupo de pesquisa da universidade.
- [Designing Data-Intensive Applications](https://www.oreilly.com/library/view/designing-data-intensive-applications/9781491903063/titlepage01.html): comparação de modelos de armazenamento, replicação, particionamento, consistência, processamento em lote e streaming.
- [DDIA companion site](https://dataintensive.net/): material complementar e referências do livro de Martin Kleppmann.
- [PostgreSQL documentation](https://www.postgresql.org/docs/current/): referência primária para o sistema usado neste projeto e para seus mecanismos de SQL, índices, transações, replicação e operação.

O curso da CMU ajuda a entender como um SGBD é construído. DDIA ajuda a comparar sistemas de dados sob requisitos de escala, falha, latência e consistência. A documentação do PostgreSQL é a fonte adequada para confirmar comportamento específico da implementação. As páginas de [transações ACID](../aprender/dados/transacoes-acid.md), [replicação](../aprender/dados/replicacao.md), [cache](../aprender/dados/cache.md) e [dados, mensageria e armazenamento](../aprender/dados/index.md) conectam esses fundamentos às decisões operacionais do repositório.

## Engenharia de software e arquitetura

- [Refactoring, de Martin Fowler](https://www.martinfowler.com/books/refactoring.html): identificação de problemas estruturais e transformações graduais que preservam comportamento.
- [Patterns of Enterprise Application Architecture](https://www.martinfowler.com/books/eaa.html): organização de aplicações, transações, acesso a dados, domínio e apresentação.
- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/): linguagem para desenhar integração por mensagens e avaliar suas consequências.
- [Software Engineering Body of Knowledge](https://www.computer.org/education/bodies-of-knowledge/software-engineering): referência da IEEE Computer Society para áreas de conhecimento da engenharia de software.
- [ISO/IEC/IEEE 12207 overview](https://www.iso.org/standard/63712.html): processos do ciclo de vida de software e sua relação com aquisição, desenvolvimento, operação e manutenção.

Essas referências não são equivalentes. Refactoring trata principalmente da estrutura interna e da evolução do código; os padrões de arquitetura tratam da organização de uma aplicação; Enterprise Integration Patterns trata das fronteiras e mensagens entre sistemas; normas descrevem processos e vocabulário para o ciclo de vida. Misturar esses níveis torna as decisões mais difíceis de revisar.

## System design, sistemas distribuídos e confiabilidade

System design combina requisitos funcionais, capacidade, latência, disponibilidade, consistência, segurança, custo, operação e evolução. Um bom material de system design não é uma coleção de arquiteturas prontas. Ele ensina a tornar as restrições explícitas e a avaliar consequências.

- [Designing Data-Intensive Applications](https://dataintensive.net/): base para discutir armazenamento, replicação, particionamento e processamento distribuído.
- [Google SRE Books](https://sre.google/books/): livros gratuitos sobre confiabilidade, operação, disponibilidade, latência, capacidade, incidentes e engenharia de software para sistemas em produção.
- [Google SRE Book](https://sre.google/sre-book/table-of-contents/): capítulos sobre SLOs, monitoramento, automação, gerenciamento de risco e operação.
- [Google SRE Workbook, system design](https://sre.google/workbook/non-abstract-design/): aplicação de princípios de confiabilidade ao desenho concreto de sistemas.
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html): conjunto de perguntas e pilares para revisar arquiteturas em nuvem.
- [Google Cloud Architecture Framework](https://cloud.google.com/architecture/framework): princípios e recomendações de operação, segurança, confiabilidade, custo, desempenho e sustentabilidade.
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/): padrões, arquiteturas de referência e guias de decisão da plataforma Azure.
- [System Design Primer](https://github.com/donnemartin/system-design-primer): material comunitário para revisão e exercícios; confirme cada decisão em fontes primárias antes de adotá-la.

As páginas de [sistemas distribuídos](../aprender/arquitetura-aplicacoes/sistemas-distribuidos.md), [resiliência](../aprender/confiabilidade/resiliencia.md), [idempotência](../aprender/confiabilidade/idempotencia.md), [cache](../aprender/dados/cache.md), [replicação](../aprender/dados/replicacao.md) e [composições de confiabilidade](../aprender/composicoes/confiabilidade/cache-cdn-replicacao-jobs.md) desenvolvem conceitos que aparecem repetidamente em system design.

## Padrões, especificações e pesquisa

Quando o assunto envolve protocolo, formato, semântica de interoperabilidade ou comportamento normativo, a fonte primária deve ter precedência sobre resumos e exemplos de blogs.

- [RFC Editor](https://www.rfc-editor.org/): RFCs de protocolos da Internet, formatos, práticas e especificações relacionadas.
- [W3C Standards and drafts](https://www.w3.org/TR/): padrões e especificações de tecnologias da Web.
- [IEEE Xplore](https://ieeexplore.ieee.org/): artigos, padrões e conferências de engenharia elétrica e computação.
- [ACM Digital Library](https://dl.acm.org/): pesquisa e anais de conferências de computação.
- [USENIX Publications](https://www.usenix.org/publications): pesquisa aplicada e relatos técnicos sobre sistemas, redes, segurança e operação.
- [arXiv](https://arxiv.org/): preprints e versões preliminares de trabalhos de pesquisa; verifique revisão por pares e versão publicada quando isso for relevante.
- [Google Scholar](https://scholar.google.com/): mecanismo de descoberta bibliográfica; use a publicação original para confirmar o conteúdo.

## Trilhas de leitura

### Fundamentos

Comece por matemática discreta, lógica, provas e análise de complexidade. Em seguida, estude algoritmos e estruturas de dados, representação de dados e sistemas operacionais. Essa base torna mais fácil entender bancos de dados, redes, concorrência e sistemas distribuídos sem tratar cada ferramenta como uma exceção isolada.

### Engenharia de aplicações

Depois dos fundamentos, use Refactoring e os padrões de arquitetura de Fowler para estudar evolução de código, limites entre camadas, transações e acesso a dados. Enterprise Integration Patterns entra quando a aplicação precisa integrar processos por mensagens, filas, eventos ou roteamento assíncrono.

### Dados e system design

Estude o funcionamento interno de um SGBD, depois compare replicação, particionamento, consistência, cache, filas e processamento de eventos em DDIA. O material de SRE acrescenta a perspectiva de operação: objetivos de nível de serviço, orçamento de erro, capacidade, incidentes e recuperação.

### Fontes locais deste repositório

- [Trilha de estudo e materiais](trilha-de-estudo-e-materiais.md): critérios para avaliar cursos, laboratórios e catálogos comunitários.
- [Blogs de engenharia](blogs-de-engenharia.md): fontes de relatos técnicos e práticas de engenharia.
- [Engenharia de software](../aprender/engenharia-software/index.md): fundamentos e práticas documentados no repositório.
- [Dados](../aprender/dados/index.md): bancos, cache, mensageria, transações e replicação.
- [Sistemas distribuídos](../aprender/arquitetura-aplicacoes/sistemas-distribuidos.md): modelos, comunicação e falhas distribuídas.
- [Resiliência](../aprender/confiabilidade/resiliencia.md): timeouts, retries, circuit breakers, fallback e limites operacionais.
