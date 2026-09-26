# Comandos de rede e DNS

Referência rápida de comandos de diagnóstico de rede e DNS. Os conceitos por trás de cada um (o caminho de uma resolução, split-horizon, DNSSEC, mDNS) estão em [aprender](../aprender/index.md); esta página é só o comando e a ressalva prática de usá-lo.

## Conectividade e rota

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `ping -c 3 example.com` | Verificar se um host responde, ou medir latência aproximada. | ICMP pode estar bloqueado por firewall mesmo com o host acessível por outro protocolo; ausência de resposta não prova indisponibilidade. |
| `nc -zv example.com 443` | Confirmar se uma porta específica aceita conexão. | Mais portável entre distribuições que `telnet`, que muitas já não incluem por padrão. |
| `ss -tlnp` | Listar conexões TCP em escuta e o processo dono de cada uma. | Lê direto das estruturas do kernel; mais rápido que o `netstat` legado em hosts com muitas conexões. `-p` exige root para ver processos de outros usuários. |
| `lsof -i :3000` | Descobrir qual processo ocupa uma porta específica. | Sem root, só mostra processos do próprio usuário; confirme o processo certo antes de encerrá-lo. |
| `mtr example.com` | Diagnosticar latência e por quais saltos uma conexão passa. | Combina `ping` e `traceroute`, atualizando estatísticas de perda por salto continuamente; roteadores intermediários podem aparecer como `*` mesmo com a rota funcionando. |
| `ip route show` | Verificar o gateway padrão ou diagnosticar roteamento. | Ferramenta recomendada hoje, do pacote `iproute2`; o `route -n` legado nem sempre vem instalado. |
| `sudo ip route add <rede> via <gateway>` | Rota customizada temporária, laboratório ou túnel manual. | Some no reboot; para persistir, configure na ferramenta de rede do sistema, não repita o comando manualmente. |

## Resolução DNS

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `dig example.com` | Verificar se um domínio resolve, com detalhe completo da resposta (TTL, tipo de registro). | Prefira a `nslookup`/`host` sempre que precisar de mais que só o endereço final. |
| `resolvectl status` | Confirmar qual resolvedor está configurado, por interface. | Em sistemas com `systemd-resolved`, editar `/etc/resolv.conf` manualmente raramente é persistente. |
| `dig @8.8.8.8 example.com` | Testar um nameserver específico, ignorando o configurado no sistema. | Útil para diagnosticar diferença de resposta entre resolvedores, como num split-horizon. |
| `dig +trace example.com` | Rastrear a cadeia completa de delegação, raiz até autoridade. | Ignora todo cache intermediário; diferencia "a zona não responde" (a cadeia quebra num salto) de "meu resolvedor tem problema" (a cadeia por `+trace` funciona, a consulta normal não). |
| `dig +dnssec example.com` | Confirmar se uma zona é assinada e se o resolvedor valida a assinatura. | A flag `ad` na resposta indica validação bem-sucedida; a ausência não distingue sozinha entre "zona não assinada" e "resolvedor não valida". |
| `dig +short example.com A` | Auditoria de zona rápida, formato fácil de processar em script. | Consultas `ANY` costumam ser bloqueadas por política; a ausência de resposta não significa ausência de registros. |
| `dig example.com MX\|TXT\|CNAME` | Validar infraestrutura de e-mail (SPF/DKIM) ou resolver aliases. | Em MX, prioridade menor significa preferência maior, fácil de interpretar ao contrário; um nome não pode ter CNAME e outro registro (como A) ao mesmo tempo. |
| `time dig example.com` | Medir latência de resolução, comparar resolvedores. | Latência consistente acima de 100ms mesmo com cache quente costuma indicar problema no caminho, não uma consulta isolada. |
| `whois example.com` / `curl rdap.org/domain/...` | Checar expiração, nameservers delegados, registrar responsável. | Não resolve o domínio, é consulta de dado de registro; RDAP devolve JSON estruturado, `whois` texto livre sem formato padronizado. |
| `avahi-resolve --name x.local` | Resolver um nome anunciado por mDNS (impressora, NAS), quando nenhum DNS convencional resolve. | Exige `avahi-daemon` ativo; um nó de cluster normalmente não deveria ter esse serviço rodando. |
| `kubectl run -it --rm debug --image=nicolaka/netshoot -- nslookup <serviço>.<namespace>.svc.cluster.local` | Diagnosticar falha de resolução de um Service interno do cluster. | Erros recorrentes nos logs do CoreDNS costumam indicar sobrecarga ou uma `NetworkPolicy` bloqueando a porta 53. |

## Continue por aqui

[Resolução, zonas e registros DNS](../aprender/resolucao-zonas-e-registros-dns.md), [DNSSEC](../aprender/rede/dns/dnssec.md), [mDNS](../aprender/rede/dns/mdns.md) e [registro de domínio](../aprender/rede/dns/registro-de-dominio.md) explicam o mecanismo por trás de cada comando acima.
