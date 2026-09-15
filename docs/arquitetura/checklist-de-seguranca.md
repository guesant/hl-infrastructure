# Checklist de segurança

Esta página compila as recomendações de dezoito guias públicos sobre segurança de GitOps, DevOps, Linux, Terraform e Kubernetes, e confronta cada uma com o que este repositório e o cluster fazem hoje. Ela complementa o [mapa de controles](mapa-de-controles.md), que parte do que o repositório garante e mostra a evidência; aqui o ponto de partida é o que a literatura pede, então aparecem também as lacunas, as recomendações que não se aplicam a um cluster de um nó só e as que foram recusadas de propósito.

A avaliação foi feita em 15 de setembro de 2026, lendo o repositório, o cluster e o node, sem alterar nada. Ela não tem marcador de deriva, porque depende de estado vivo que nenhum gate enxerga, então vale reler a tabela depois de uma mudança grande de infraestrutura e atualizar a data.

## As fontes

Cada recomendação da tabela cita as fontes pelo código da primeira coluna. Algumas páginas não puderam ser lidas por inteiro, e isso está registrado: um item que só aparece numa fonte lida em parte vale menos do que um que várias fontes repetem.

| Código | Fonte | Recorte | Leitura |
| --- | --- | --- | --- |
| RG | [Security and Compliance in GitOps: Best Practices and Challenges](https://www.researchgate.net/publication/388173617_Security_and_Compliance_in_GitOps_Best_Practices_and_Challenges), ResearchGate | GitOps, conformidade | Só o resumo; a página recusa acesso automatizado |
| CP | [Hardening Git for GitOps](https://control-plane.io/posts/hardening-git-for-gitops/), ControlPlane, 2021 | Git e GitHub como fonte da verdade | Completa |
| PL | [GitOps Security Checklist: Top Best Practices](https://www.plural.sh/blog/gitops-security-checklist-tips/), Plural, 2025 | GitOps de ponta a ponta | Completa |
| CN | [The 16-Point Checklist for GitOps Success](https://www.cncf.io/blog/2022/07/08/the-16-point-checklist-for-gitops-success/), CNCF, 2022 | Adoção e operação de GitOps | Completa |
| CY | [Guide to secure GitOps systems](https://cycode.com/blog/guide-to-secure-gitops-systems/), Cycode, 2024 | O agente de GitOps como alvo | Completa, mas curta; o detalhe está numa palestra à parte |
| LU | [DevOps security checklist](https://lumenalta.com/insights/devops-security-checklist), Lumenalta | DevOps, processo e pipeline | Parcial |
| TS | [linux-hardening-checklist](https://github.com/trimstray/linux-hardening-checklist), trimstray | Hardening de servidor Linux | Completa; algumas seções do original estão vazias |
| PS | [Linux Hardening: Secure Server Checklist](https://www.pluralsight.com/resources/blog/tech-operations/linux-hardening-secure-server-checklist), Pluralsight, 2022 | Hardening de servidor Linux | Completa |
| HC | [Terraform security: 5 foundational practices](https://www.hashicorp.com/pt/blog/terraform-security-5-foundational-practices), HashiCorp, 2025 | Uso seguro de Terraform e OpenTofu | Completa |
| HV | [Security hardening](https://developer.hashicorp.com/validated-designs/terraform/installation-guide/security-hardening), HashiCorp Validated Designs | Operação do Terraform Enterprise | Completa; quase tudo trata de hospedar o TFE |
| TG | [terraform-compliance-guardrails CHECKLIST.md](https://github.com/levansula23/terraform-compliance-guardrails/blob/main/CHECKLIST.md), levansula23 | Revisão de PR de Terraform em AWS sob HIPAA, SOC 2, GDPR e HITRUST | Completa; a maior parte é específica de AWS e de conformidade |
| K8 | [Security Checklist](https://kubernetes.io/docs/concepts/security/security-checklist/), documentação do Kubernetes | Cluster | Completa |
| KA | [Application Security Checklist](https://kubernetes.io/docs/concepts/security/application-security-checklist/), documentação do Kubernetes | Workloads | Completa |
| SR | [kubernetes-hardening-checklist-guidance](https://github.com/seifrajhi/kubernetes-hardening-checklist-guidance), seifrajhi | Hardening de cluster | Completa |
| SE | [A practical guide to Kubernetes security](https://sealos.io/blog/a-practical-guide-to-kubernetes-security-hardening-your-cluster-in-2025/), Sealos, 2025 | Hardening de cluster | Completa |
| MD | [Kubernetes Hardening & Optimization Checklist](https://medium.com/@sudhakar.bhat247/kubernetes-hardening-optimization-checklist-6a1129cef04a), Medium | Hardening e custo | Ver a seção de Kubernetes |
| DO | [DevOps Security: Your Complete Checklist](https://devops.com/devops-security-your-complete-checklist/), DevOps.com | DevOps | Só resumos de busca; a página bloqueia acesso automatizado |
| AC | [The DevOps Security Checklist Redux](https://github.com/altercation/SecurityChecklists/blob/main/devops-security-checklist.md), altercation, 2021 | Cultura, código, infraestrutura e monitoramento | Completa |

## Como ler a tabela

Cada linha junta recomendações equivalentes de fontes diferentes numa frase só, escrita para este contexto. O status diz o que vale hoje:

- **Atende**: o controle existe e tem evidência no repositório, no cluster ou no node.
- **Parcial**: existe, mas com um buraco conhecido que a coluna de situação descreve.
- **Não atende**: não existe hoje.
- **Não se aplica**: pressupõe algo que este ambiente não tem, como uma equipe, uma nuvem pública ou um Terraform Enterprise.
- **Recusado**: foi considerado e ficou de fora por decisão, com o motivo na própria linha.

## Repositório e GitHub

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Branch principal sem force-push e sem exclusão | Atende | Ruleset `preservacao` com `non_fast_forward` e `deletion` | CP, PL, CY, TG |
| Merge só por pull request com checks obrigatórios | Parcial | O ruleset exige PR e o job `gate`, mas o dono está isento e hoje empurra direto em `main`; cada push aparece como bypass | CP, PL, CY, TG |
| Revisão por outra pessoa antes do merge | Não se aplica | Um operador só; `required_approving_review_count` é zero, e o `ci` substitui o segundo par de olhos no que é automatizável | CP, PL |
| Aprovação extra para mudanças sensíveis (RBAC, políticas de rede, projetos do Argo) | Parcial | `CODEOWNERS` cobre `argocd/root/`, os workflows e o `justfile`, mas sem segunda pessoa a revisão é só formal | CP, PL, CY |
| Commits assinados e assinatura verificada na CI | Não atende | Nenhum dos últimos cinquenta commits de `main` é assinado, e o ruleset não exige assinatura | CP, PL |
| Chave de assinatura em hardware | Não atende | Depende de haver assinatura; a identidade SOPS do operador já vive na Secure Enclave, mas a do git não | CP |
| MFA na conta do Git | Atende | Declarado no [modelo de ameaças](modelo-de-ameacas.md) como a proteção real de `main`; a API não expõe esse dado para conferência automática | CP, PL, LU, AC |
| Repositório de configuração privado | Recusado | O repositório é público de propósito, como portfólio; por isso nenhum valor sensível fica em texto claro, os IDs da Cloudflare ficam cifrados e o `gitleaks` varre o histórico | PL |
| Configuração do GitHub como código, conferida periodicamente | Não atende | Rulesets e opções do repositório foram feitos à mão no GitHub; o Scorecard semanal só enxerga parte disso | CP |
| Backup do repositório fora do GitHub, com restauração testada | Não atende | O clone local do operador é a única cópia fora do GitHub | CP |
| Log de auditoria do GitHub enviado para fora | Não atende | Sem SIEM; o histórico de bypass do ruleset fica só no GitHub | CP, PL |
| Política de divulgação de vulnerabilidade | Atende | `SECURITY.md` e o relato privado de vulnerabilidade do GitHub ligado | AC |
| Varredura de segredo no push | Atende | Secret scanning e push protection do GitHub ligados, mais o job `gitleaks` sobre o histórico | PL, AC |

## CI/CD e supply chain

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Pipeline versionada e tratada com o mesmo cuidado do produto | Atende | Workflows no git, `permissions` mínimas, sem `persist-credentials`, auditados por `actionlint` e `zizmor` | AC, CP |
| Actions, imagens e binários pinados | Atende | Actions por SHA, charts e binários por versão com checksum, `FROM` do Dockerfile de ferramentas por digest mantido pelo Renovate, e `pip install --require-hashes` no workflow `docs` a partir de `docs/requirements.in` | HC, PL |
| Atualização contínua de dependências vulneráveis | Atende | Renovate com sete dias de carência e `osv-scanner` na CI | AC, LU, PL |
| Varredura de dependências e imagens, bloqueando achados graves | Atende | `osv-scanner`, `trivy-fs` e `trivy config` no `gate` | PL, LU, AC |
| Lint e análise estática dos manifestos e da IaC | Atende | `kubeconform`, `kube-linter`, `checkov`, `trivy config`, `ansible-lint`, `tofu validate` | PL, CP |
| SAST no código | Não se aplica | Este repositório não tem código de aplicação; o blog tem os próprios gates no repositório dele | LU, AC |
| DAST contra o que está no ar | Não atende | Nada testa o blog publicado | LU, AC |
| Imagens assinadas e verificadas na admissão | Não atende | O Image Updater só aceita tags `sha-<commit>`, mas nenhuma assinatura é conferida | CP, K8, SR |
| Nota pública de práticas do repositório | Atende | OpenSSF Scorecard semanal e a cada push, com o resultado no code scanning | PL |
| Webhook do Git disparando a sincronização | Atende | Webhook do GitHub em `ops.guesant.net/api/webhook`, validado por assinatura | CN |

## Segredos

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Nenhum segredo em texto claro no git | Atende | SOPS com age para `SopsSecret` e `tofu/**/*.sops.env`; job `sopssecrets` confere que todo arquivo está cifrado para os destinatários atuais | PL, RG, AC, TG |
| Segredo entregue ao workload por um componente dedicado, com trilha de acesso | Parcial | O sops-secrets-operator decifra no cluster; o audit log do API server registra leitura de `Secret` e de `SopsSecret` em nível de metadados, mas não há cofre externo | CN, PL, AC |
| Chave mestra fora de disco e com uso auditado | Parcial | A identidade do operador fica na Secure Enclave e a de desastre no cofre de senhas; a do node fica num `Secret` do cluster | AC |
| Rotação periódica | Atende | Job `secret-age` com prazo por arquivo e `just sops-rotate` | LU |
| Segredos fora do state da IaC | Atende | O token do túnel nunca passa pelo OpenTofu, e o state é cifrado com `enforced = true` | HC, TG |
| Segredos mascarados nos logs da CI | Atende | A CI não recebe credencial de decifragem; nada sensível chega a ela para ser impresso | TG |

## GitOps e Argo CD

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Tudo declarado no git: apps, rede e configuração | Parcial | Workloads, políticas e túnel estão no git; o Argo CD em si e o k3s vêm do Ansible, também versionado, mas aplicados à mão | CN, PL |
| Deriva detectada e corrigida automaticamente | Atende | `automated` com `selfHeal` e prune nas `Application` que já passaram pelo diff inicial | CN |
| Escopo mínimo por projeto | Atende | Projeto `satellites` só cria recurso de namespace mais `StorageClass`; `default` esvaziado | PL, CY |
| Interface do agente de GitOps fora da internet | Atende | `argocd-server` é `ClusterIP`; o túnel só publica o caminho exato do webhook, o resto do hostname responde 404 | CY |
| Login local de administrador desligado, identidade central com SSO | Não atende | `admin.enabled` continua `true` e não há OIDC; o acesso depende de quem tem o kubeconfig | PL |
| RBAC do Argo CD restrito | Não atende | `policy.default` e `policy.csv` vazios; na prática só existe o admin | PL, CY |
| Terminal nos pods pela interface desligado | Atende | `exec.enabled` é `false` | SR |
| Agente de GitOps num cluster separado do que ele gerencia | Não se aplica | Um nó só; a mitigação equivalente é o escopo por projeto e o `argocd-server` sem exposição | CY |
| Pipeline testada em ambientes que não são produção | Não se aplica | Não há outro ambiente; o dry-run do bootstrap e o `diff` antes de ligar `automated` fazem esse papel | CN |
| Mudança em produção só em horário comercial | Não se aplica | Homelab de uma pessoa | CP |

## Kubernetes

A fonte SR republica o guia de hardening de Kubernetes da NSA e da CISA, de 2022, que ainda fala em PodSecurityPolicy; a recomendação equivalente hoje é o Pod Security Admission, e é assim que a tabela a registra. A fonte MD descreve o que uma equipe implantou, com boa parte dedicada a custo e desempenho; só os itens de segurança entraram. As duas foram lidas por um leitor intermediário, sem acesso ao texto cru.

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| API server fora da internet, só de redes confiáveis | Atende | Porta 6443 só dos CIDRs em `k3s_api_allowed_cidrs`, filtrada na chain `INPUT` | K8, SR, SE |
| Autenticação anônima desligada no API server e no kubelet | Atende | `anonymous-auth=false` no API server; os dois respondem 401 sem credencial, e a porta read-only 10255 está fechada | SR, SE |
| Nenhum binding para `system:unauthenticated` além do mínimo | Atende | Só o `system:public-info-viewer` padrão, que expõe versão e saúde | KA |
| RBAC com privilégio mínimo e sem conceder criação de roles | Parcial | Revisado em 2026-09-15: curinga só no `argocd-application-controller` (aplica qualquer recurso, por desenho do GitOps), no `argocd-server` (ações da interface), no sops-secrets-operator (cria `Secret` em qualquer namespace) e nos componentes do k3s; o kube-bench roda com ClusterRole só de leitura; a revisão periódica confere se aparece curinga novo | K8, KA, SR, SE |
| `system:masters` só no bootstrap | Parcial | O kubeconfig do operador é o de administrador do k3s; não há usuário nominal com permissão menor | K8 |
| Kubeconfig com leitura restrita | Atende | Na máquina do operador fica fora do git, com modo 600; no node, `write-kubeconfig-mode: "0600"` deixa `/etc/rancher/k3s/k3s.yaml` legível só pelo root | SR |
| Plugins de admissão recomendados, incluindo `NodeRestriction` | Atende | `NodeRestriction` ligado, junto com os padrões do k3s | K8 |
| Pod Security Standards aplicados em todo namespace | Atende | `enforce`, `warn` e `audit` `restricted` em `blog`, `argocd`, `cert-manager`, `cnpg-system` e `sops`, por `managedNamespaceMetadata` nos operadores, por um manifesto `Namespace` no projeto `infra` para o `blog` e pela role `argocd`; `kube-system` fica sem enforce porque o Cilium e o k3s precisam de privilégio; o job `pod-security` exige o label em todo namespace novo | K8, KA, SR, SE |
| Motor de políticas na admissão (Kyverno, Gatekeeper, ValidatingAdmissionPolicy) | Não atende | As regras só existem como gate de CI sobre os charts renderizados | SE, MD, PL, CP |
| Contêiner sem privilégio, sem escalada, com capabilities removidas | Atende | Todos os pods de `argocd`, `blog`, `cert-manager`, `cnpg-system` e `sops` rodam `runAsNonRoot` com `drop: ALL` e sem escalada | KA, SR, SE |
| Perfil seccomp `RuntimeDefault` | Atende | Presente em todos os pods, inclusive no sops-secrets-operator depois de ligar o `securityContext` do chart | K8, KA, SE |
| Sistema de arquivos raiz somente leitura | Atende | Em todos os pods de `argocd`, `blog`, `cert-manager`, `cnpg-system` e `sops`; o app do blog escreve só em `emptyDir` | KA, SR, SE |
| AppArmor ou SELinux nos contêineres | Parcial | AppArmor ligado no node, com o perfil padrão do containerd; nenhum perfil próprio por workload | K8, KA, SE |
| Token de ServiceAccount só onde o pod usa a API | Atende | O chart do blog e do cloudflared já renderiza `automountServiceAccountToken: false`, e os pods não têm o volume `kube-api-access` | K8, KA, SR, SE |
| ServiceAccount própria por workload | Atende | Os operadores têm a sua, e o blog e o cloudflared passaram a criar a própria em vez de usar `default` | KA, SE |
| Plugin de rede com suporte a NetworkPolicy | Atende | Cilium com `enable-policy: always` | K8, SR, SE |
| `default-deny` de entrada e saída, liberando só o necessário | Parcial | O Cilium já nega tudo por padrão (`enable-policy: always`) e cada namespace tem uma `CiliumNetworkPolicy` com o que usa, mas `policyAuditMode: true` continua ligado: a virada para bloquear espera o Hubble ficar sem veredictos `AUDIT` | K8, KA, SR, SE |
| Tráfego entre pods cifrado | Não atende | Sem WireGuard nem IPsec no Cilium; num nó só o tráfego não sai da máquina | K8, SE, MD |
| Saída e DNS controlados contra vazamento de dados | Parcial | Cada namespace só sai para o CoreDNS, para o API server e para as portas externas de que precisa (443 no Argo CD e no app do blog, 7844 e 443 no cloudflared); vale de verdade quando o modo auditoria for desligado | SE |
| `LoadBalancer`, `NodePort` e `externalIPs` restritos | Atende | Só há `Service` `ClusterIP`; Traefik e ServiceLB desligados pela role `k3s` | K8 |
| Acesso de pods à API de metadados de nuvem bloqueado | Não se aplica | Raspberry Pi, sem serviço de metadados | K8, SR |
| `Secret` cifrado em repouso | Atende | `secrets-encryption` ligado pela role `k3s`, com recifragem dos `Secret` que já existiam; a chave fica só no node | K8, SR, SE |
| Nada confidencial em `ConfigMap` | Atende | As credenciais do blog saíram do `ConfigMap` para o `SopsSecret` `app-secret` | K8 |
| `Secret` montado como volume em vez de variável de ambiente | Atende | As credenciais do blog chegam como arquivos em `/secrets/app`, lidos pelo `AddKeyPerFile` do ASP.NET, com modo 0440 e `fsGroup` do usuário do app; nenhuma aparece no ambiente do processo | SE |
| Datastore isolado, com TLS e acesso só do API server | Atende | k3s com sqlite local, sem porta de rede | SR, SE |
| Backup do datastore, cifrado, fora do node e com restauração testada | Não atende | Nenhum snapshot; a reconstrução parte do git e perde o que só existia no cluster | SE |
| Audit log do API server ligado, com política e rotação | Atende | `audit-policy.yaml`, `audit-log-maxage=30`, rotação por tamanho, arquivo com modo 600 | K8, SR, SE |
| Audit log e logs dos contêineres enviados para fora, imutáveis | Não atende | Tudo fica no disco do node | SR, SE |
| Detecção em runtime (Falco, Tetragon) | Não atende | Hubble está ligado, mas só como observação | SE, SR |
| `requests` e `limits` de memória nos workloads | Atende | Blog, Postgres, Argo CD, cert-manager, CNPG, sops-secrets-operator, Image Updater e Cilium com `requests` e limite de memória; CoreDNS, metrics-server e local-path-provisioner são addons do k3s e ficam com os valores dele | K8, KA, SR, SE |
| Imagem sem conteúdo desnecessário e com usuário sem privilégio | Parcial | O blog roda com UID 1654 e sem root; o conteúdo da imagem é responsabilidade do repositório do blog | K8, SR |
| Imagem referenciada por digest ou assinatura verificada | Parcial | Argo CD, dex, operadores, Cilium, cloudflared e Postgres por digest, mantido pelo Renovate; o blog por tag `sha-<commit>`, o redis do Argo CD e os addons do k3s por tag; nenhuma assinatura verificada | K8, SE |
| Varredura de imagens no build e no deploy | Atende | O blog varre a própria imagem no build, e o job `trivy-images` varre toda imagem implantada, falhando em CVE crítica com correção fora do `.trivyignore.yaml` com prazo | K8, KA, SR, SE |
| SBOM e atestados de proveniência | Parcial | O job `trivy-images` gera um SBOM CycloneDX por imagem implantada; ainda não há assinatura nem atestado de proveniência | SE |
| Isolamento de workloads sensíveis por nó ou runtime isolado | Não se aplica | Um nó só; gVisor e Kata não compensam no Raspberry Pi | K8, SR, SE, MD |
| Namespaces separados por função | Atende | Um por operador, um para o Argo CD e um para o blog | SR, SE, MD |
| Benchmark CIS periódico (kube-bench) | Parcial | `CronJob` semanal com o perfil `k3s-cis-1.9`, só nas checagens de `policies`; as de master e node dependem de `journalctl` e dos argumentos do processo `k3s`, que um pod não enxerga, e ficam para uma execução no próprio node; a primeira execução apontou curingas em roles de operadores, a ServiceAccount `default` em uso pelo `argocd-redis` e tokens montados onde não são usados; o resumo no Discord entra junto com os alertas | SR, SE |
| Correções de segurança aplicadas logo | Parcial | Renovate propõe versões novas de k3s e charts, mas o k3s só muda com um novo `bootstrap` manual | SR, SE |

## OpenTofu

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Providers com origem e versão fixas, lock file commitado | Atende | `cloudflare` pinado em versão exata e `.terraform.lock.hcl` no git | HC |
| Credencial do provider fora do código, com privilégio mínimo | Atende | API token só com Tunnel e DNS, injetado por `sops exec-env`, nunca em arquivo | HC, TG |
| Credenciais separadas para `plan` e `apply` | Parcial | `.tools/tofu-run.sh` usa `CLOUDFLARE_API_TOKEN_READ` nos comandos que só leem (`plan`, `show`, `output`, `state list`) e o token de escrita no resto; falta criar o token só de leitura no dashboard e gravá-lo cifrado, e até lá os comandos de leitura avisam e usam o de escrita | HC |
| Credenciais de vida curta, por OIDC | Não se aplica | O provider da Cloudflare não emite credencial dinâmica; a rotação com prazo cobre parte do risco | HC |
| State protegido e fora do alcance de quem não opera | Atende | State cifrado com `enforced = true`, passphrase em SOPS | HC, TG |
| Variáveis sensíveis marcadas como `sensitive` | Atende | IDs de conta e zona e a passphrase | HC |
| Mudança de state só pela CLI e por import versionado | Atende | A virada do domínio foi feita com `tofu import` e plano salvo, sem editar o state | HC |
| `plan` revisado antes do `apply`, procurando exclusões inesperadas | Atende | `just tofu-apply` confirma; os applies de risco usaram plano salvo e conferido | TG, PL |
| Política como código sobre os recursos | Atende | Conftest com políticas próprias para a Cloudflare no job `tofu`, além de `trivy config` e `checkov` sobre `tofu/` | HC, PL |
| Proteção contra destruição acidental | Atende | `prevent_destroy` nos registros do apex e do `www`, exigido por uma política do Conftest no job `tofu` | TG |
| Controles de hospedagem do Terraform Enterprise | Não se aplica | O OpenTofu roda local, num container, sem servidor | HV |
| Controles de conformidade AWS, HIPAA, GDPR e afins | Não se aplica | Nada roda em AWS e não há dado regulado | TG |

## Node

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| SSH só por chave, sem senha e sem login vazio | Atende | `PasswordAuthentication no`, `PermitEmptyPasswords no`, conferidos no `sshd -T` | PS, AC |
| Root sem login por SSH | Recusado | `PermitRootLogin prohibit-password`: o Ansible entra como root por chave; trocar por um usuário com `sudo` é possível, mas não muda o que a chave permite | PS |
| Limite de tentativas e banimento de quem insiste | Atende | `MaxAuthTries 3` e `fail2ban` com a jail `sshd` | PS, AC |
| SSH fora da porta 22 e com lista de usuários permitidos | Parcial | `AllowGroups root`, `LoginGraceTime 30` e `LogLevel VERBOSE`; a porta continua 22, e o acesso só a partir de origens conhecidas fica para a fase seguinte | PS |
| Firewall ligado, só com o necessário exposto | Atende | firewalld só libera SSH e 6443 na zona pública, e o `rpcbind`, que escutava em todas as interfaces sem uso, fica parado e mascarado pela role `os_prerequisites` | PS |
| Atualizações de segurança automáticas | Atende | `unattended-upgrades` habilitado | AC, PS |
| MAC aplicando perfis | Atende | AppArmor ligado com perfis em `enforce` para o que roda; os perfis em `complain` (servidor gráfico, desktop, build de pacotes, cliente de torrent, `unix-chkpwd` e `unprivileged_userns`) são de pacotes da imagem que nada no node executa, conferido na revisão de 2026-09-15, e forçá-los a `enforce` não protegeria processo nenhum | TS, PS |
| Auditoria de chamadas de sistema | Atende | `auditd` vigia identidade (`passwd`, `shadow`, `group`, `sudoers.d`), SSH, firewalld, cron, carga de módulos do kernel e as credenciais e a configuração do k3s | TS |
| sysctls de rede e kernel endurecidos | Atende | `randomize_va_space`, `tcp_syncookies`, `kptr_restrict=2`, `dmesg_restrict=1`, redirects e source route desligados em IPv4 e IPv6, `suid_dumpable=0`; `ip_forward` fica ligado porque o Kubernetes precisa | TS, PS |
| Partições separadas e opções de montagem restritas | Parcial | `/tmp` é tmpfs com `nosuid,nodev,noexec` e `/dev/shm` com `nosuid,nodev`; `/var`, `/var/log` e `/home` continuam dividindo a raiz | TS, PS |
| Disco cifrado | Não atende | Sem LUKS; o [modelo de ameaças](modelo-de-ameacas.md) já deixa acesso físico fora do perímetro | PS, TS |
| Senha de firmware, boot só pelo disco, módulo USB bloqueado | Não se aplica | Raspberry Pi sem BIOS configurável; fica coberto pela premissa de acesso físico fora do modelo | PS |
| Política de senha, bloqueio por falhas e expiração | Não se aplica | Não há login por senha em nenhum usuário | TS, PS |
| Relógio sincronizado | Atende | NTP ligado e sincronizado | AC |
| Logs enviados para fora do node | Não atende | Journal local, sem coletor remoto | TS, AC, LU |
| Inventário documentado do host | Atende | `ansible/inventory.ini` e o [estado fora do git](../operacional/estado-fora-do-git.md) | PS, AC |

## Observabilidade, backup e resposta

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Logs centralizados e alertas de atividade anômala | Não atende | Não há métricas, logs centralizados nem alertas; é a lacuna que o [mapa de controles](mapa-de-controles.md) já aponta | LU, AC, PL, CP |
| Detecção de intrusão ou de comportamento em runtime | Não atende | Hubble observa o tráfego, mas nada alerta sobre ele | LU, SR |
| Monitoramento de expiração de certificado e de domínio | Atende | O TLS público é da Cloudflare e renova sozinho, e o job `domain-expiry` consulta o RDAP e falha na execução agendada a trinta dias do vencimento | AC |
| Backup de tudo que é crítico, com restauração testada | Não atende | O Postgres do blog não tem backup desde a remoção do barman; só `.sops.yaml` e o state têm cópia, no git | AC, CP |
| Plano de resposta a incidente e revisão pós-incidente | Atende | [Resposta a incidente](../operacional/resposta-a-incidente.md) com conter, preservar evidência, erradicar e recuperar, e um exercício trimestral junto da revisão periódica | LU, AC |
| Proteção contra DDoS e WAF na frente do serviço público | Parcial | O tráfego passa pelo proxy da Cloudflare, com a proteção de DDoS do plano gratuito; nenhuma regra de WAF foi configurada | AC |

## Governança

| Recomendação | Status | Situação aqui | Fontes |
| --- | --- | --- | --- |
| Responsabilidades e processo de mudança escritos | Atende | [Metodologia de mudança](../operacional/metodologia-de-mudanca.md) e o [checklist operacional](../operacional/checklist.md) | CN, LU |
| Modelo de ameaças explícito | Atende | [Modelo de ameaças](modelo-de-ameacas.md) | LU, DO |
| Revisão periódica de permissões e de exposição | Atende | Roteiro em [revisão periódica](../operacional/revisao-periodica.md), última em 2026-09-15, prazo de 90 dias em `.config/security-review.conf`, cobrado pelo job `secret-age` | LU, AC |
| Teste de invasão e bug bounty | Não se aplica | Fora da escala de um homelab; o relato privado de vulnerabilidade cobre o canal de entrada | LU, AC |
| Conformidade com normas (SOC 2, ISO 27001, GDPR, HIPAA) | Não se aplica | Nenhum dado regulado nem cliente | RG, TG, AC |
| Treinamento e exercícios de phishing | Não se aplica | Uma pessoa; a seção [Aprender](../aprender/index.md) faz o papel de material de estudo | LU, AC |

## O que atacar primeiro

Nem toda lacuna pesa igual. As abaixo mudam o risco real do cluster e são baratas perto do que protegem.

A política de rede ainda não bloqueia. Desde 15 de setembro de 2026 cada namespace tem uma `CiliumNetworkPolicy` com o que usa, e o Hubble deixou de mostrar veredictos `AUDIT` logo depois de elas entrarem, mas o Cilium continua com `policyAuditMode: true`, então as regras só registram o que barrariam e qualquer pod ainda alcança o Postgres do blog. A pendência é virar esse modo, e o procedimento é este: a partir de 17 de setembro de 2026, conferir no Hubble (`hubble observe --type policy-verdict --verdict AUDIT`, dentro do agente) que nenhum veredicto `AUDIT` apareceu em coletas espalhadas por pelo menos dois dias, incluindo um sync do Argo CD, uma troca de imagem pelo Image Updater e um push com webhook; trocar `policyAuditMode` para `false` em `ansible/roles/cilium/templates/values.yaml.j2` e rodar `just bootstrap`; depois confirmar que só tráfego esperado aparece como `DROPPED`, que todas as `Application` seguem Healthy e que o blog, o login com Google e o webhook continuam funcionando. Se algo parar, `cilium config set policy-audit-mode true` no agente devolve o modo auditoria na hora, antes de reverter o commit.

Os dados do blog não têm backup. Enquanto o banco estiver vazio isso não custa nada, mas o primeiro post publicado muda a conta, e a restauração precisa ser testada, não só configurada.

O Argo CD mantém o login local de administrador. Ele não está exposto na internet, mas quem obtiver a senha inicial ou o kubeconfig administra o cluster pela interface, sem trilha de identidade própria.

## Continue por aqui

O [mapa de controles](mapa-de-controles.md) lista a evidência de cada controle que já existe, e o [modelo de ameaças](modelo-de-ameacas.md) diz de que cada um protege.
