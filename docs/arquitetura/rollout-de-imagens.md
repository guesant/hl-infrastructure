# Rollout de imagens

<!-- source-of-trust paths="argocd/apps/platform/kargo argocd/applications/platform/kargo.yaml argocd/apps/satellites/delivery argocd/applications/satellites/delivery.yaml" -->

O Kargo está instalado como serviço de plataforma. O chart de entrega pode gerar projetos, warehouses e stages para satélites que publicam imagens; a lista em `argocd/apps/satellites/delivery/values.yaml` está vazia, portanto não há rollout de imagem de satélite configurado atualmente.

O site Hugo é gerado e publicado pelo GitHub Pages. Ele não usa imagem de container, Warehouse ou Stage no cluster. Para acrescentar outro serviço ao fluxo do Kargo, declare-o na lista de satélites e revise o manifesto renderizado antes da sincronização.

Os detalhes do chart e das permissões do Kargo estão em [Kargo](../aprender/entrega/kargo/index.md), e o processo para cadastrar um satélite está em [adicionar um satélite novo](../operacional/adicionar-um-satelite.md).
