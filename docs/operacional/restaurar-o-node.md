# Restaurar o node do zero

<!-- source-of-trust paths=".sops.yaml .tools/sops-recipients.sh .tools/sops-drill.sh .tools/sops-sync.sh .tools/sops-rotate.sh" -->

Este runbook cobre a perda total do node: cartão SD corrompido, hardware trocado, ou um comprometimento em que a única resposta segura é reinstalar. O ponto de partida é um Raspberry Pi OS limpo com SSH por chave e acesso como root, exatamente como no [primeiro bootstrap](primeiro-bootstrap.md). A diferença está no que precisa ser recuperado de fora do git, listado em [estado fora do git](estado-fora-do-git.md).

## 1. Reconstruir o cluster

Na máquina do operador, o inventário continua válido se a máquina do operador sobreviveu; se não, recrie-o a partir do exemplo. O arquivo de segredos do Ansible vem do próprio repositório, cifrado, e decifra com a identidade da Secure Enclave ou com a chave de recuperação. É esse arquivo que carrega o token de join do k3s e a chave de autorização do Tailscale, então sem uma identidade capaz de abri-lo o bootstrap não sai do lugar.

Um node reinstalado tem host keys novas, e o `.local/operator/known_hosts` antigo faz o Ansible recusar a conexão, de propósito. Do lado do cliente, uma reinstalação e alguém no meio do caminho são o mesmo evento, e quem desfaz essa ambiguidade é você, lendo a impressão digital no console físico do Pi. Confira as impressões digitais novas no console do Pi e grave o arquivo de novo, como no [primeiro bootstrap](primeiro-bootstrap.md), antes de seguir:

```bash
ssh-keyscan <IP do Pi> | tee .local/operator/known_hosts | ssh-keygen -lf -
```

```bash
just preflight
just bootstrap-check
just bootstrap
```

Ao fim, o kubeconfig aponta para o cluster novo e a listagem de aplicações mostra o root sincronizando os satélites. O k3s reinstalado recebe o token declarado na variável de join, o mesmo que o node antigo usava, então nada precisa ser recuperado nem regravado: o valor nunca deixou de existir, porque sempre foi o git quem o guardava.

Essa garantia vale para o token, e não para o estado do node em geral: a chave age do sops, tratada no passo 2, é o caso oposto, gerada no próprio node e perdida junto com ele.

A imagem do Raspberry Pi OS cria de novo o usuário padrão (`user`, uid 1000), com senha, grupo sudo, chave SSH e login automático tanto no desktop gráfico quanto no console de texto. Nada do cluster usa esse usuário, e o Ansible não o remove, então o passo é manual, por SSH como root, depois de confirmar que a lista de chaves autorizadas do root tem a chave do operador.

Essa confirmação não é formalidade: os comandos abaixo desligam o login automático e apagam a conta que seriam o outro caminho de entrada, e fazê-los na ordem errada deixa o node sem nenhum acesso.

```bash
systemctl set-default multi-user.target
systemctl disable --now lightdm
rm -rf /etc/systemd/system/getty@tty1.service.d && systemctl daemon-reload && systemctl restart getty@tty1
loginctl terminate-user user; userdel -r -f user
```

Não use `pkill -u user` nem espere o comando de remoção de usuário sem forçar passar: vários contêineres do cluster rodam com uid 1000, o mesmo número do usuário da imagem, então o pkill derruba pods de operadores e a remoção sempre encontra processos com esse uid.

A flag de forçar só remove a conta e a home; os contêineres continuam rodando com o número de uid, que não depende da entrada no arquivo de usuários. Errar isso custa caro para um passo cosmético: derrubar pods de operador no meio de uma reconstrução contamina o diagnóstico de tudo o que vier depois.

Depois disso não existe login pelo console local: o root continua com a senha bloqueada e só entra por SSH com chave. Perder o SSH passa a significar tirar o disco e corrigi-lo em outra máquina. O custo já está aceito de propósito, porque um console com login automático num node que roda o cluster inteiro equivale a acesso irrestrito para quem alcançar a máquina.

O túnel e o DNS da Cloudflare não fazem parte desta reconstrução: eles vivem na conta da Cloudflare, não no node, e continuam existindo. O cloudflared volta sozinho quando o Argo sincroniza o satélite do blog, com o token que já está no `SopsSecret`, desde que o passo 2 abaixo deixe a chave do node nova capaz de decifrá-lo. Nenhum `just tofu` é necessário aqui.

O Keycloak, ao contrário, nasce vazio num node novo: o StatefulSet sobe contra um banco sem usuário nenhum, e nenhum realm existe. Antes do primeiro apply, crie o segredo `keycloak-bootstrap-admin` como descrito em [primeiro bootstrap](primeiro-bootstrap.md), com a mesma senha que o arquivo de segredos do módulo master declara como credencial; o pod o lê por uma referência de ambiente opcional e cria esse usuário só porque o realm master está vazio.

Essa referência é opcional, então o StatefulSet sobe igual quando esse segredo não existe, que é o estado normal de um cluster já configurado; a ausência dele não é falha.

Os states dos módulos do Keycloak ainda apontam para os IDs da instância antiga, então o caminho é o do bootstrap inicial, precedido de uma remoção de state ou de um novo init num state vazio.

Aplicar o módulo master recria os realms, o administrador e as contas de serviço; os outros módulos recriam o conteúdo, a recipe de bootstrap do administrador aposenta o administrador temporário novo, e a recipe de usuário recria os seus usuários, cujas senhas e TOTP se perderam com o banco.

O administrador temporário existe só nessa janela, entre o realm vazio e a aplicação do módulo; mantê-lo depois seria deixar no ar uma credencial de administração sem dono.

Os client secrets não mudam, porque vivem nos `SopsSecret`, então Grafana, Argo CD, Portainer, oauth2-proxy e o blog voltam a autenticar sem nenhuma alteração. O que não volta são as contas humanas e os seus segundos fatores, que existiam só no banco do Keycloak. Essa assimetria é o desenho: segredo de máquina vive no git, cifrado, e credencial de pessoa não.

## 2. Confirmar a chave age

Um node novo não herda a chave age do node antigo: a role da chave age só gera uma chave quando o segredo `sops-age-key-file` ainda não existe, e num node recém-instalado ele nunca existe. O bootstrap do passo 1 gera uma chave nova, diferente da anterior.

Enquanto isso não é corrigido, todo segredo cifrado continua decifrável pelas outras chaves listadas no arquivo de destinatários do SOPS, a de rotina do operador na Secure Enclave, a de desastre no Bitwarden, ou qualquer outra que tenha sido adicionada, então este passo não é urgente, mas precisa ser feito antes de encerrar a reconstrução:

```bash
just sops-recipients sync-node
```

O comando lê a chave pública do node vivo e reescreve só a entrada rotulada node no arquivo de destinatários, sem tocar nas outras; revise o diff e commite. O rótulo node é o padrão do subcomando de sincronização, e você passa outro se este cluster convive com mais de um node no mesmo arquivo.

A leitura vem do segredo `sops-age-key-file` pelo kubeconfig local, então o cluster precisa estar de pé para o comando funcionar, e só a metade pública da chave atravessa: a privada nunca sai do node.

Rode a recipe de sincronização em seguida para recifrar todo segredo já commitado para os destinatários atuais. Ela só pede uma identidade que decifre se algum arquivo realmente precisar ser decifrado para resincronizar os destinatários, então ter a chave de rotina do operador ou a de desastre à mão só importa nesse caso.

A varredura não se limita aos segredos do Kubernetes: ela alcança também os arquivos de ambiente do OpenTofu e as variáveis cifradas do Ansible, de modo que nenhum deles fica para trás por esquecimento.

Sem esse passo, os segredos continuam decifráveis pelas chaves que não mudaram, só não ficam recifrados para a chave nova do node até a próxima vez que alguém os editar. O gate de segredos cifrados, que roda no check local e no job de mesmo nome na CI, deixa esse atraso visível: ele falha assim que os destinatários de algum segredo divergirem do arquivo atual, então um push sem a sincronização correspondente não passa despercebido.

Rodar o check antes do push é o que evita descobrir a divergência pela CI, com o node já reconstruído e a atenção em outro lugar.

Se as outras chaves também se perderam junto com o Mac do operador, não há como recuperar o que já estava cifrado. Este é o cenário terminal do modelo de chaves, e ele não tem atalho: sem nenhuma identidade que decifre, o conteúdo cifrado no git é ruído.

O caminho passa a ser recomeçar, com chaves novas e os valores originais buscados na fonte de cada segredo: gere um par novo com `just age-se-keygen`, ou um par de desastre novo com `just age-keygen`, adicione o destinatário no arquivo de destinatários, e recifre cada segredo de cada satélite a partir do valor original:

```bash
just sops-sync <caminho-do-sops-secret-em-texto-claro>
```

O valor original de cada segredo só existe onde o satélite o gerou (o token do túnel no painel da Cloudflare, as chaves do bucket no provedor). Commite os `SopsSecret` recifrados nos satélites; o Argo aplica no próximo ciclo. Vale aproveitar a passagem para rotacionar cada segredo na origem, já que uma perda de chave dessa escala costuma vir junto com dúvida sobre o que mais foi exposto.

## 3. O Postgres não tem backup hoje

O Cluster do CNPG no satélite do blog sobe vazio, com um banco novo e vazio: o backup contínuo em object storage foi desligado de propósito, e o operador de backup que o fazia funcionar nem está instalado hoje. Não há armazenamento de objeto nem agendamento de backup declarados, então não existe recuperação possível; os dados que estavam no volume do node perdido não são recuperáveis por este runbook.

Se o backup for religado no futuro, este passo volta a valer o formato de referência de recuperação do CNPG, com um bloco `bootstrap.recovery` apontando para o armazenamento externo, e esta seção deve ser reescrita para descrevê-lo de novo.

## 4. Conferir

Passe pelo [checklist operacional](checklist.md) inteiro. Os itens de SSH, firewall e API são os que mais importam aqui, porque a máquina é nova e nenhuma regra foi conferida nela ainda. Rode também `just sops-drill-se`, que percorre a árvore cifrada inteira e reporta OK ou FAIL por arquivo, confirmando de uma vez que a troca de destinatários do passo 2 não deixou nada sem quem o abra.

## Continue por aqui

O [modelo de ameaças](../arquitetura/modelo-de-ameacas.md) explica quais cenários terminam neste runbook.
