# Aviso sobre conteúdo assistido por IA

Parte do código, da configuração e da prosa deste repositório foi escrita ou revisada com assistência de um modelo de linguagem, trabalhando lado a lado com o operador humano que assina os commits e aprova cada mudança. Isso vale tanto para os arquivos de Ansible, OpenTofu e Helm quanto para esta documentação.

Isso não substitui a revisão humana, mas muda o tipo de erro que vale a pena procurar. Um erro de digitação ou uma sintaxe errada normalmente já foi pega pelos gates de CI antes de chegar em `main`. O que um gate automatizado não pega é uma afirmação plausível e bem escrita que descreve um comportamento levemente diferente do que o código realmente faz, porque o texto nasceu de um resumo do código, não da leitura do código por quem lê a página agora. Antes de seguir um comando, uma versão ou um valor específico desta documentação num contexto onde o erro custaria caro, vale conferir contra o arquivo que ele descreve.

O commit de cada página fica no histórico do git como de costume, sem marcação separada para o que teve assistência de IA e o que não teve; a autoria de uma mudança é de quem a revisou e commitou, não de qual ferramenta ajudou a escrevê-la.

## Continue por aqui

[Convenções de escrita](convencoes-de-escrita.md) descreve o estilo que toda página segue, incluindo as instruções que o operador dá para manter esse estilo.
