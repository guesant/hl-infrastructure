# OpenTofu: a camada da Cloudflare

<!-- source-of-trust paths="tofu .tools/tofu-run.sh .tools/tofu-state-passphrase.sh .tools/cloudflare-tunnel-token.sh" -->

O Ansible prepara o node e o Argo CD cuida de tudo que roda dentro do cluster, mas o caminho de um visitante até o blog começa fora dos dois: no DNS da Cloudflare e no túnel que liga a borda da Cloudflare ao cloudflared dentro do cluster. [tofu/cloudflare](https://github.com/guesant/hl-infrastructure/tree/main/tofu/cloudflare) declara essa parte com OpenTofu, e o resto desta página explica o que ele possui, o que ele deliberadamente não possui e por quê.

## O que o OpenTofu declara

Três recursos: o túnel `blog` (`cloudflare_zero_trust_tunnel_cloudflared`), a configuração de ingress desse túnel (`cloudflare_zero_trust_tunnel_cloudflared_config`) e o registro CNAME do hostname do blog apontando para `<id do túnel>.cfargotunnel.com`. O túnel é remotamente gerenciado (`config_src = "cloudflare"`): as regras de ingress moram na própria Cloudflare, e o cloudflared no cluster não carrega arquivo de configuração nenhum, só o token que o identifica. As regras são as mesmas que antes viviam numa `ConfigMap` do chart do cloudflared: `/api/webhook` segue para o `argocd-server`, o resto do hostname segue para o `Service` do app, e qualquer outra coisa recebe 404.

Esse desenho cria um acoplamento que nenhum gate pega: os destinos do ingress são nomes de `Service` do cluster (`app.blog.svc.cluster.local`, `argocd-server.argocd.svc.cluster.local`), declarados em outro sistema. Renomear um desses `Service` num chart do Argo sem mudar `tunnel.tf` quebra o túnel sem nenhum erro de CI; a mudança precisa ir nos dois lugares no mesmo commit.

## O que ele não possui, de propósito

O token que o cloudflared usa para se conectar nunca passa pelo OpenTofu. O provider da Cloudflare até oferece um data source que lê esse token, mas qualquer valor lido por um data source vai parar no state, e marcar um atributo como `sensitive` só o esconde da saída do terminal, não o tira do arquivo. Em vez disso, [.tools/cloudflare-tunnel-token.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/cloudflare-tunnel-token.sh) (via `just cloudflare-tunnel-token`) lê do state só o ID do túnel, pede o token direto à API da Cloudflare e o grava recifrado no `SopsSecret` do cloudflared com `sops set --idempotent`, sem arquivo intermediário em texto claro. A fonte da verdade desse token é a Cloudflare; o `SopsSecret` é uma cópia cifrada para entrega.

O API token que autoriza o OpenTofu a mexer na conta também não é recurso dele. É um token único, criado à mão no dashboard, com só duas permissões (Cloudflare Tunnel de edição na conta e DNS de edição na zona do blog). Um token com permissão de criar outros tokens deixaria o OpenTofu gerenciar credenciais, mas seria praticamente a conta inteira num segredo só, e o valor de cada token criado cairia no state; para um operador só, isso aumenta o risco sem resolver problema nenhum.

## Como as credenciais chegam ao processo

Os segredos ficam em dois níveis, porque respondem a perguntas diferentes. `tofu/state.sops.env` é comum a todo o OpenTofu e guarda só a passphrase do state (`TF_VAR_state_passphrase`, que o OpenTofu entrega a `var.state_passphrase` pela convenção do prefixo `TF_VAR_`). Cada módulo guarda as credenciais do próprio provider num arquivo com o nome dele, como `tofu/cloudflare/cloudflare.sops.env`, com só o API token da Cloudflare. Assim um módulo futuro, de outro provider, nunca recebe o token da Cloudflare no ambiente.

`just tofu <módulo> <argumentos>` chama [.tools/tofu-run.sh](https://github.com/guesant/hl-infrastructure/blob/main/.tools/tofu-run.sh), que se reexecuta por dentro de um `sops exec-env` para cada um dos dois arquivos: cada `exec-env` decifra os valores só no ambiente do processo filho. No fim, o script roda `docker run` com a imagem oficial do OpenTofu, passando `-e NOME` para exatamente as variáveis que os dois arquivos declaram (os nomes ficam em texto claro num arquivo SOPS de ambiente; só os valores são cifrados). Passar `-e NOME` sem valor faz o Docker herdar a variável do ambiente, então o segredo não aparece na linha de comando nem toca o disco. O custo de dois arquivos é a Secure Enclave poder pedir biometria duas vezes por execução. A decifragem acontece no host, e não dentro do container, pelo mesmo motivo de `sops-edit` e `sops-sync`: a identidade de rotina do operador vive na Secure Enclave do Mac e não funciona fora dele.

O provider `carlpett/sops`, que decifraria o arquivo de dentro do próprio OpenTofu, ficou de fora. Configuração de provider não é gravada no state, então `exec-env` já mantém o API token fora dele; nenhum dos três recursos recebe segredo como argumento, então recursos efêmeros e atributos write-only não teriam onde ajudar; e decifrar dentro do container esbarraria na Secure Enclave de novo.

A regra de `.sops.yaml` para `tofu/**/*.sops.env` é separada da regra dos `SopsSecret` e não tem `encrypted_suffix`. Isso não é detalhe: a regra dos `SopsSecret` só cifra o que está sob `secretTemplates`, e um arquivo de ambiente que caísse nela sairia "cifrado" com todo valor em texto claro. O gate `security-sopssecrets` confere os dois tipos de arquivo.

## State cifrado dentro do git

O state fica em `tofu/cloudflare/terraform.tfstate`, commitado, cifrado pela state encryption nativa do OpenTofu: um key provider `pbkdf2` derivando a chave da passphrase, método `aes_gcm`, e `enforced = true` tanto para state quanto para plan, o que faz o OpenTofu recusar gravar qualquer um dos dois em texto claro se a configuração de cifragem sumir. Commitar evita um serviço novo só para guardar um arquivo pequeno, e o que ele contém é pouco sensível mesmo decifrado (IDs de conta, zona e túnel, e o registro DNS), justamente porque nenhum token passa pelo OpenTofu. O custo é não ter lock de concorrência, aceitável com um operador só, e o histórico do git guardar states antigos, todos cifrados.

Perder a passphrase não derruba nada: o túnel e o DNS continuam existindo na Cloudflare. O caminho é gerar uma passphrase nova e reconstruir o state com `tofu import` dos três recursos. Trocar a passphrase de propósito usa um bloco `fallback` com a antiga durante uma execução, que lê com a antiga e grava com a nova.

Ninguém digita a passphrase. `just tofu-state-passphrase` a gera com `openssl rand -base64 48` e a entrega direto ao `sops encrypt` por um pipe, então o valor nunca aparece no terminal, nunca vai para argumento de processo e nunca toca o disco em texto claro; gerar uma do zero nem exige identidade que decifre, porque cifrar só usa as chaves públicas. O script recusa gerar outra por cima quando algum `terraform.tfstate` já existe, porque uma passphrase nova trancaria esses states. Para esse caso existem `--rotate`, que guarda a atual como `TF_VAR_state_passphrase_previous` antes de gerar a nova, e `--finish-rotation`, que descarta a antiga depois que todo módulo regravou o state; os dois precisam decifrar a atual, então pedem a identidade do operador.

A passphrase é uma só para todo módulo. Passphrases separadas não isolariam nada de verdade, porque quem decifra um arquivo SOPS deste repositório decifra todos. O bloco `encryption`, por outro lado, fica repetido em cada root module, de propósito. O OpenTofu aceitaria a mesma configuração pela variável de ambiente `TF_ENCRYPTION`, sem repetir HCL, mas aí a cifragem dependeria de rodar pela recipe: um `tofu apply` executado à mão, sem a variável, não teria configuração de cifragem nenhuma e gravaria o state em texto claro. Com o bloco no HCL e `enforced = true`, esse engano vira erro em vez de vazamento.

## Na CI e no Renovate

O job `tofu` roda `tofu fmt -check` e, para cada módulo em `tofu/`, `tofu validate` com `init -backend=false` e uma passphrase fictícia, sem credencial nenhuma, e o `trivy config` passa a incluir o scanner de Terraform sobre o repositório. `plan` na CI ficou de fora de propósito: exigiria dar à CI uma chave capaz de decifrar o API token. O Renovate atualiza o provider e o `.terraform.lock.hcl` pelo gerenciador nativo, respeitando os sete dias de maturidade do repositório (a razão de o provider estar pinado numa versão exata, já que minors do provider v5 da Cloudflare mudaram schema de recursos de túnel), e `opentofu_version` no `justfile` por um gerenciador de regex; `required_version` fica fora do Renovate porque ele o compararia com versões do Terraform, não do OpenTofu.

## Continue por aqui

O passo a passo para criar o API token e aplicar pela primeira vez está em [primeiro bootstrap](../operacional/primeiro-bootstrap.md); rotacionar o token do túnel ou o API token está em [rotacionar credenciais](../operacional/rotacionar-credenciais.md).
