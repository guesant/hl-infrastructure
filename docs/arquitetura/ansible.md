# Ansible: as roles do bootstrap

`ansible/site.yml` aplica quinze roles em sequência, numa única play contra o host `pi`. A ordem importa: cada role assume que a anterior já deixou o sistema num estado específico, e várias delas verificam essa suposição explicitamente antes de continuar (a role `cilium`, por exemplo, aborta se o arquivo de configuração declarativo do k3s ainda não desabilitou o kube-proxy embutido).

## Hardening de sistema operacional

As primeiras seis roles não instalam nada de Kubernetes; elas preparam o sistema operacional.

`os-prerequisites` instala pacotes base, ajusta os parâmetros de cgroup que o k3s e o containerd exigem, e libera as portas e CIDRs necessários no firewalld, incluindo os CIDRs internos de pod e serviço que o Cilium vai usar depois. `unattended_upgrades` liga atualizações automáticas de segurança. `sysctl_hardening` aplica parâmetros de kernel recomendados, verificando primeiro se cada parâmetro existe no kernel do host antes de tentar defini-lo. `auditd` liga auditoria de chamadas de sistema. `ssh_hardening` autoriza a chave pública declarada em `ssh_root_authorized_key` e restringe `PermitRootLogin` a autenticação por chave. `fail2ban` bane automaticamente origens com tentativas repetidas de login SSH inválido.

## Plataforma Kubernetes

`k3s` instala o k3s pelo script oficial, com o backend de rede padrão e o kube-proxy embutido desabilitados via `/etc/rancher/k3s/config.yaml`, porque o Cilium assume essas duas responsabilidades a seguir. `cilium` verifica que o k3s já desabilitou o que precisa, então instala o Cilium via chart Helm oficial, com `policyEnforcementMode: always` e `policyAuditMode: true` (as políticas de rede são avaliadas e logadas, mas nada é bloqueado ainda) e o Hubble ligado para observabilidade.

`cnpg` instala o operador CloudNativePG, que passa a entender a CRD `Cluster` que qualquer aplicação no cluster pode usar para pedir um banco Postgres. `cert-manager` instala o cert-manager. `cnpg-barman-plugin` instala o plugin de backup Barman Cloud do CNPG; diferente de todos os outros componentes desta lista, ele não tem chart Helm oficial ainda, então é o único que continua sendo aplicado a partir de um manifesto vendorizado.

`argocd` instala o ArgoCD e registra o segredo compartilhado do webhook do GitHub. `sealed-secrets` instala o controlador que decripta os `SealedSecret` aplicados pelo Argo, sem que o texto plano do segredo jamais passe pela cadeia de sincronização do Argo. `argocd-image-updater` instala o componente que detecta e aplica sozinho novas tags de imagem publicadas.

## A ponte para o GitOps

`bootstrap-app` é a última role, e a única que aplica manualmente uma `Application` do Argo: a aplicação `root`, descrita em [GitOps: root e satélites](gitops-root-e-satelites.md). A partir do momento em que ela existe no cluster, tudo o que acontece depois é responsabilidade do Argo, não do Ansible.

## Continue por aqui

Para ver por que seis dessas roles instalam via chart Helm em vez de manifesto vendorizado, veja [Helm e os charts](helm-e-charts.md).
