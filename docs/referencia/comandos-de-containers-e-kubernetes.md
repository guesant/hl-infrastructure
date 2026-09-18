# Comandos de containers e Kubernetes

## Docker

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `docker ps -a` | Confirmar que um container está rodando, ou achar um que parou. | Sem `-a`, só mostra containers em execução; a coluna `STATUS` indica `Up`, `Exited`, `Paused`. |
| `docker logs -f -t --tail 100 <container>` | Depurar uma aplicação ou investigar um erro. | `-f` segue em tempo real, `-t` acrescenta timestamp por linha, `--tail` evita despejar todo o log acumulado. |
| `docker exec -it <container> /bin/sh` | Depurar o estado interno de um container. | Só funciona em container já rodando; imagens minimalistas (Alpine) não têm Bash, `/bin/sh` é mais portável. |
| `docker inspect --format='{{.NetworkSettings.IPAddress}}' <container>` | Descobrir configuração, rede ou volumes montados. | `--format` filtra o JSON completo para um campo específico via template Go, mais prático em automação que processar tudo. |
| `docker images -f dangling=true` | Confirmar disponibilidade local ou achar candidatas a limpeza. | `SIZE` é o tamanho descompactado, não o transferido no pull; imagens dangling são camadas sem tag de builds anteriores sobrescritos. |
| `docker rm -f <container>` / `docker image prune` | Limpeza de espaço ou remoção de containers falhos. | `-f` encerra abruptamente um container rodando; `image prune` só remove dangling, `-a` remove também não usadas mas ainda tagueadas, com mais risco de remover algo que seria reaproveitado. |
| `docker build -t myapp:1.0 .` | Criar uma imagem a partir de um Dockerfile. | O `.` final é o contexto de build (o que é enviado ao daemon), não necessariamente onde está o Dockerfile; ordenar o Dockerfile para copiar dependências antes do código aproveita melhor o cache de camadas. |
| `docker push myregistry/myapp:1.0` | Publicar uma imagem num registry. | `docker login` salva credenciais em `~/.docker/config.json`, em texto não cifrado sem um credential helper; prefira token de escopo limitado a senha de conta, principalmente em CI. |

## Kubernetes

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `kubectl cluster-info` / `kubectl get nodes` / `kubectl top nodes` | Health check geral, confirmar se a API responde. | `top nodes` exige metrics-server instalado; sem ele, o comando falha. |
| `kubectl get pods -A -o wide` | Ver o que está rodando ou achar Pods travados/falhos. | `--field-selector=status.phase!=Running` isola Pods problemáticos num cluster grande. |
| `kubectl logs <pod> --previous` | Ver logs de um container que já reiniciou. | Por padrão `kubectl logs` mostra só o container atual; os logs do container anterior a um crash só aparecem com `--previous`. |
| `kubectl describe pod <pod>` | Entender por que um Pod não iniciou (erro de pull, por exemplo). | A seção `Events` no final costuma ser o primeiro lugar a olhar, antes de qualquer log de aplicação. |
| `kubectl exec -it <pod> -- /bin/sh` | Depurar o estado interno ou inspecionar o filesystem de um Pod. | Imagens `distroless` podem não ter nem `/bin/sh`; o `--` separa as flags do `kubectl` do comando executado dentro do container. |
| `kubectl port-forward svc/<service> 8080:80` | Acessar um serviço interno via localhost sem expô-lo publicamente. | Por padrão escuta só em `127.0.0.1`; `--address 0.0.0.0` amplia quem pode acessar, use com o mesmo cuidado de qualquer porta exposta. |
| `curl http://<service>.<namespace>.svc.cluster.local:<porta>` | Testar conectividade entre serviços dentro do cluster. | De dentro de um Pod no mesmo namespace, o namespace pode ser omitido no nome. |
| `kubectl top pod --sort-by=memory` | Diagnosticar um `OOMKilled` ou identificar throttling de CPU. | Mostra uso atual, não série histórica; para tendência ao longo do tempo, uma stack de métricas como a descrita em [Stack Prometheus, Loki e Grafana](../aprender/stack-prometheus-loki-grafana.md) é o caminho certo. |
| `kubectl describe pod <pod> \| grep -A3 "Limits\|Requests"` | Confirmar se um Pod tem limites de recursos definidos. | Ver [Requests, limits e QoS de um Pod](../aprender/requests-limits-e-qos-de-um-pod.md) para o que cada um efetivamente controla. |

## Continue por aqui

[Diagnóstico de Pod, nó, certificado e Argo CD](../aprender/diagnostico-de-pod-no-cluster-e-do-argocd.md) e [Requests, limits e QoS de um Pod](../aprender/requests-limits-e-qos-de-um-pod.md) explicam o que está por trás de vários desses comandos.
