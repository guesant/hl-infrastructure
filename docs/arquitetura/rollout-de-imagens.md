# Rollout de imagens

O Argo CD só reage quando o manifesto renderizado muda de texto; ele não sabe, por si só, que uma imagem nova foi publicada num registry enquanto a tag declarada continua a mesma. É por isso que o padrão deste repositório, descrito em [adicionar um satélite novo](../operacional/adicionar-um-satelite.md), sempre usa uma tag imutável por commit (`sha-<commit>`) e deixa o Argo CD Image Updater escolher a mais recente que bate com esse padrão, em vez de uma tag móvel como `latest` ou `main` que o Argo CD nunca perceberia sozinho. Esta página cobre duas armadilhas do Image Updater que não aparecem na documentação oficial dele, e que travam a atualização de imagem em silêncio quando acontecem.

## O sintoma: nada acontece, e não há erro nenhum

O Image Updater roda como um controller comum, com seu próprio ciclo de reconciliação (por padrão, a cada dois minutos); sem um webhook do registry configurado, é esse polling que dita o atraso entre a imagem ficar pronta e o cluster perceber. Isso já é esperado. O problema real é quando o controller simplesmente para de considerar uma imagem, sem nenhum evento de erro visível em `kubectl get events` nem em `Application.status`, só uma linha no log do pod:

```text
level=info msg="Image '...' seems not to be live in this application, skipping" application=...
```

Isso acontece porque o Image Updater decide se uma imagem está "viva" lendo `Application.status.summary.images`, e esse campo pode vir vazio de um bug conhecido e ainda aberto do próprio Argo CD ([argoproj/argo-cd#27861](https://github.com/argoproj/argo-cd/issues/27861)), sem relação com nada configurado neste repositório. A mitigação documentada pelo próprio mantenedor do Image Updater ([argoproj-labs/argocd-image-updater#791](https://github.com/argoproj-labs/argocd-image-updater/issues/791)) é pular essa checagem de liveness:

```yaml
commonUpdateSettings:
  updateStrategy: newest-build
  allowTags: regexp:^sha-[0-9a-f]{40}$
  forceUpdate: true
```

Com `forceUpdate: true`, o controller reaplica o resultado a cada ciclo em vez de só quando o valor muda; isso não causa um rollout novo à toa, porque quem decide reiniciar o pod é o Argo CD comparando o manifesto renderizado, não o Image Updater. Se um satélite tiver o Image Updater aparentemente ocioso (`Running`, sem erro, mas nenhuma imagem atualiza nunca), essa linha no log é o primeiro lugar a olhar, antes de suspeitar de RBAC ou de rede.

## O outro sintoma: a imagem sobe com o nome errado

O Image Updater sempre escreve o resultado da estratégia escolhida no parâmetro Helm apontado por `helm.image-tag`, mas o formato desse valor muda com a estratégia: `newest-build` (a usada aqui) escreve só a tag; `digest` escreve a tag e o digest já concatenados, `tag@sha256:...`, num único texto. Se `helm.image-tag` apontar para um campo que o chart depois combina de novo com uma tag estática de outro lugar dos values, a referência de imagem final sai duplicada e inválida (`repo:tag@tag@sha256:...`), e o pod novo nunca sobe, com `InvalidImageName`.

Isso não é um risco hoje, porque `newest-build` escreve só a tag simples e o satélite existente aponta `helm.image-tag` para o campo de tag do próprio chart. Vale checar antes de trocar de estratégia num satélite novo: renderize o chart com `helm template` depois de configurar o Image Updater, e confirme visualmente que o campo de imagem final tem o formato esperado, em vez de assumir que qualquer campo aceita qualquer estratégia.

## Continue por aqui

[Adicionar um satélite novo](../operacional/adicionar-um-satelite.md) mostra a configuração completa do `ImageUpdater` que este repositório usa hoje; [GitOps: root e satélites](gitops-root-e-satelites.md) explica por que uma tag imutável por commit, e não uma tag móvel, é a base de todo esse mecanismo.
