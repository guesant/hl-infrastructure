# Trilha de estudo e materiais

## Fundamento antes de nuvem

Para quem opera uma arquitetura parecida com a deste repositório (Kubernetes via distribuição enxuta, GitOps, observabilidade própria, CNI baseado em eBPF), a ordem de estudo que rende mais no longo prazo segue um princípio simples: certificações de nuvem testam como um provedor específico resolve compute, rede, storage e IAM, mas presumem que quem faz a prova já entende os conceitos gerais de Kubernetes de forma agnóstica de provedor. Estudar um serviço gerenciado de Kubernetes de um provedor de nuvem antes de entender Kubernetes em si é otimizar sintaxe específica sobre uma base conceitual ainda incompleta. Uma progressão razoável começa pelo fundamento do próprio Kubernetes, segue por hardening e pelas ferramentas do ecossistema já em uso real (GitOps, observabilidade, e o CNI escolhido, se for além do padrão de fábrica da distribuição), e só depois avança para a primeira certificação de nuvem, o serviço de Kubernetes gerenciado dessa nuvem, e por fim uma certificação de DevOps avançada, essa última só depois de experiência real operando o ambiente, não em sequência imediata à certificação anterior.

Duas variações fazem sentido dependendo do objetivo: um foco em segurança prioriza profundidade de hardening sobre amplitude de ferramentas do ecossistema, adiando as certificações de projeto individual em favor de uma trilha de segurança mais cedo; um foco em migrar o eixo de carreira para nuvem gerenciada inverte a prioridade, adiando ou pulando as certificações de ferramentas específicas do ecossistema em favor de avançar mais rápido para arquitetura e operação de nuvem.

## Critérios para avaliar um recurso de estudo pago

Nenhum material deveria ser escolhido só pela nota média de quem avaliou; antes de pagar por um curso, livro ou laboratório, os mesmos critérios valem para qualquer recurso. A data da última atualização de conteúdo importa mais que a data em que alguém deixou uma avaliação, porque um curso desatualizado há alguns anos pode ensinar uma versão de API que já nem existe mais. Quem é o autor ou instrutor, e se essa pessoa efetivamente opera a tecnologia (contribuição em projeto aberto, histórico de produção real) ou só reempacota documentação oficial em formato de vídeo, é a segunda pergunta que vale fazer. A terceira é se existe alternativa gratuita equivalente: a documentação oficial e laboratórios interativos gratuitos já cobrem boa parte do que um curso pago vende, então pagar só faz sentido de verdade quando o valor real está na curadoria e na ordem de estudo, não no conteúdo em si, que já é público em outro lugar. Por fim, política de reembolso e acesso a atualizações futuras do material importa especialmente para certificações cujo escopo de prova muda periodicamente.

## Laboratórios e knowledge bases gratuitos

- [Kubernetes.io: Tutorials](https://kubernetes.io/docs/tutorials/): tutoriais interativos oficiais, mantidos pelo próprio projeto.
- [Killercoda](https://killercoda.com/): laboratórios interativos gratuitos, incluindo cenários específicos de preparação para as certificações práticas da CNCF.
- [Kubernetes Failure Stories](https://k8s.af/): coleção de relatos reais de incidentes em produção com Kubernetes, agrupados por causa, uma leitura que ensina pela falha alheia em vez da teoria isolada.

## Catálogos `awesome-*`

Um catálogo comunitário do tipo `awesome-*` é útil para descoberta, nunca para reuso direto sem avaliação própria: antes de copiar um exemplo de qualquer um deles, confira a data da última release, mantenedores ativos, licença, imagens oficiais, checksums ou assinaturas, e o privilégio que a ferramenta exige, exatamente os mesmos critérios de [Avaliar ferramentas de operação](../aprender/avaliar-ferramentas-de-operacao.md).

- [CNCF Cloud Native Landscape](https://landscape.cncf.io/): projetos organizados por categoria; presença no mapa não equivale a recomendação ou maturidade CNCF.
- [Awesome Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted): serviços livres hospedáveis pelo próprio usuário.
- [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes) e [Awesome K8s Tools](https://github.com/vilaca/awesome-k8s-tools): projetos e ferramentas para Kubernetes, catálogo amplo o suficiente para exigir confirmação de atividade item a item.
- [Awesome Sysadmin](https://github.com/awesome-foss/awesome-sysadmin): software livre para administração de sistemas.
- [Awesome Security](https://github.com/sbilly/awesome-security): mistura ferramentas defensivas e ofensivas; definir autorização e ambiente isolado antes de testar qualquer item da lista não é opcional.

## Continue por aqui

[Certificações de infraestrutura e nuvem](../aprender/certificacoes-de-infraestrutura-e-nuvem.md) cobre a distinção entre certificação, badge e avaliação prática que fundamenta as escolhas desta trilha. [Avaliar ferramentas de operação](../aprender/avaliar-ferramentas-de-operacao.md) detalha os critérios aplicados aqui aos catálogos comunitários.
