# Rollout de imagens

<!-- source-of-trust paths="argocd/apps/platform/kargo argocd/applications/platform/kargo.yaml argocd/apps/satellites/delivery argocd/applications/satellites/delivery.yaml" -->

O Kargo permanece instalado como serviço de plataforma, mas não há satélites configurados para publicar imagens. A aplicação de entrega e seus recursos foram removidos enquanto a lista de satélites estiver vazia.

O site Hugo é gerado e publicado pelo GitHub Pages. Ele não usa imagem de container, Warehouse ou Stage no cluster. Para voltar a usar o Kargo, adicione um satélite e revise o manifesto renderizado antes da sincronização.

Os detalhes do chart e das permissões do Kargo estão em [Kargo](../aprender/entrega/kargo/index.md), e o processo para cadastrar um satélite está em [adicionar um satélite novo](../operacional/adicionar-um-satelite.md).
