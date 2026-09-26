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
| `kubectl describe pod <pod> \| grep -A3 "Limits\|Requests"` | Confirmar se um Pod tem limites de recursos definidos. | Ver [requests](../aprender/kubernetes/recursos/requests.md), [limits](../aprender/kubernetes/recursos/limits.md) e [QoS](../aprender/kubernetes/recursos/qos.md) para o que cada um efetivamente controla. |

## PostgreSQL (CloudNativePG)

| Comando | Quando usar | Observação |
| --- | --- | --- |
| `kubectl --namespace <namespace> port-forward service/<cluster>-rw <porta-local>:5432` | Abrir acesso administrativo pontual a um cluster PostgreSQL do CloudNativePG. | O sufixo `-rw` aponta para a instância de leitura e escrita; `-ro` serve réplicas de leitura e `-r` qualquer instância. O comando fica em primeiro plano, então mantenha o terminal aberto durante toda a sessão do cliente. |
| `kubectl --namespace <namespace> get secret <cluster>-superuser --output jsonpath='{.data.password}' \| base64 --decode` | Obter a senha do superusuário para uma conexão administrativa. | Cada cluster tem o próprio `Secret` de superusuário; use essa credencial só para administração, nunca para a aplicação. |
| `psql "postgresql://postgres@127.0.0.1:<porta-local>/postgres" -c 'SELECT 1;'` | Validar que o `port-forward` e a credencial funcionam antes de conectar um cliente gráfico. | Um retorno diferente de `1`, ou `connection refused`, geralmente indica que o `port-forward` caiu em outro terminal. |

Com o `port-forward` ativo, qualquer cliente gráfico compatível com libpq (DBeaver, DataGrip, HeidiSQL, pgAdmin, Beekeeper Studio) se conecta pelos mesmos dados.

| Campo | Valor |
| --- | --- |
| Host | `127.0.0.1` |
| Porta | a porta local escolhida no `port-forward` |
| Usuário | `postgres` (administrativo) ou o usuário de aplicação |
| Banco | `postgres` ou o banco de destino |
| SSL | `prefer` ou `require`, conforme a configuração do cluster |

Um driver com SSL padrão `verify-full` (comum em DBeaver e DataGrip) tende a falhar contra o certificado interno do cluster nessa conexão local; use `prefer`.

Um pgAdmin rodando como container precisa apontar para `host.docker.internal`, ou o IP do host em Linux, porque `127.0.0.1` dentro do próprio container não alcança o encaminhamento rodando no host. O Beekeeper Studio aceita importar direto a string `postgresql://usuario:senha@127.0.0.1:5432/banco`.

## Docker Compose: fragmentos de serviço

Um serviço básico do Compose declara imagem, porta publicada, variável de ambiente e política de reinício:

```yaml
services:
  app:
    image: nginx:latest
    ports:
      - "8080:80"
    environment:
      ENV_VAR: "value"
    restart: unless-stopped
```

Combine um bind mount com um named volume quando parte dos dados vem do host e parte é gerenciada pelo próprio Docker:

```yaml
services:
  app:
    image: myapp
    volumes:
      - ./data:/app/data
      - app_cache:/app/cache

volumes:
  app_cache:
```

A declaração `volumes:` que nomeia um named volume precisa ficar no nível raiz do arquivo, irmã de `services:`; declará-la dentro do serviço é um erro comum que o Compose rejeita ou interpreta errado.

Serviços numa mesma rede customizada se enxergam pelo nome do serviço, sem precisar de IP:

```yaml
services:
  web:
    image: nginx
    networks:
      - backend
  api:
    image: myapi
    networks:
      - backend

networks:
  backend:
    driver: bridge
```

Um `healthcheck` marca o container como `unhealthy` depois de falhas consecutivas do teste, e `start_period` dá uma carência inicial antes que essas falhas comecem a contar:

```yaml
services:
  api:
    image: myapi:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

Por padrão, `depends_on` garante só que o container dependido já iniciou, não que ele está pronto para aceitar conexão; para esperar por uma condição de saúde real, combine a forma estendida `condition: service_healthy` com um `healthcheck` no serviço dependido.

```yaml
services:
  web:
    image: nginx
    depends_on:
      - api
  api:
    image: myapi
    depends_on:
      - db
  db:
    image: postgres
```

Variáveis de ambiente podem vir diretamente do serviço, com um valor padrão embutido, ou de um arquivo externo carregado à parte; quando as duas formas definem a mesma variável, a declarada diretamente no serviço tem precedência.

```yaml
services:
  app:
    image: myapp
    environment:
      - DB_HOST=db
      - DB_PORT=5432
      - DEBUG=${DEBUG:-false}
    env_file: .env
```

Um serviço também pode construir a imagem localmente a partir de um Dockerfile, em vez de baixar uma já publicada; o campo `image` opcional nomeia a imagem resultante, útil para reutilizá-la fora do Compose.

```yaml
services:
  myapp:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        VERSION: "1.0"
    image: myapp:latest
```

O Compose combina automaticamente `docker-compose.yml` com `docker-compose.override.yml` no mesmo diretório, sem exigir flag adicional; é a forma comum de manter a definição de produção no arquivo principal e sobrescrever só o necessário para desenvolvimento local.

```yaml
# docker-compose.yml
services:
  app:
    image: myapp:prod
    restart: always
```

```yaml
# docker-compose.override.yml (aplicado junto ao arquivo principal)
services:
  app:
    build: .
    restart: "no"
    volumes:
      - .:/app
```

## Fragmentos de manifesto Kubernetes

Deployment mínimo, com três réplicas selecionadas pelo label `app: myapp`; este exemplo omite requests, limits e probes de propósito, veja as seções correspondentes logo abaixo antes de usar algo assim em produção:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:1.0
          ports:
            - containerPort: 8000
```

Um `Service` expõe o Deployment dentro do cluster:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8000
  type: ClusterIP
```

| Tipo de Service | Alcance |
| --- | --- |
| `ClusterIP` | só de dentro do cluster (padrão) |
| `NodePort` | uma porta fixa em cada nó |
| `LoadBalancer` | exige um provisionador externo integrado, o que normalmente não é o caso de um K3s bare metal sem um componente adicional como o MetalLB |

Um `ConfigMap` guarda dados de configuração como objeto separado do Deployment; monte-o como volume apontando o nome do ConfigMap e o caminho de destino dentro do container:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.conf: |
    server {
      listen 8000;
    }
  debug: "true"
```

```yaml
# Trecho do Deployment que consome o ConfigMap acima
spec:
  template:
    spec:
      volumes:
        - name: config
          configMap:
            name: app-config
      containers:
        - volumeMounts:
            - name: config
              mountPath: /etc/app
```

Codificação em base64 não é criptografia: qualquer leitura de um `Secret` decodifica o valor trivialmente. Nunca versione um Secret com valor real em texto no Git.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=      # "admin", codificado em base64
  password: cGFzc3dvcmQ=  # valor de exemplo, nunca use em produção
```

```yaml
# Trecho do container que consome o Secret acima
containers:
  - name: app
    env:
      - name: DB_USER
        valueFrom:
          secretKeyRef:
            name: db-secret
            key: username
```

`requests` é o valor reservado para o container na decisão de agendamento, não um teto; `limits` é o teto de consumo real. Ultrapassar o limite de memória causa `OOMKilled`; ultrapassar o de CPU só causa throttling, sem encerrar o processo.

```yaml
containers:
  - name: app
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
```

A liveness probe reinicia o container quando falha repetidamente; a readiness probe só remove o Pod da lista de endpoints prontos de um Service, sem reiniciá-lo. Não use o mesmo endpoint com a mesma semântica para as duas: uma dependência externa lenta não deveria derrubar a liveness, só a readiness.

```yaml
containers:
  - name: app
    livenessProbe:
      httpGet:
        path: /health
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 8000
      initialDelaySeconds: 5
```

Este notebook usa a Gateway API, não o `Ingress` clássico, como forma padrão de expor serviços via HTTP. Veja o fragmento de Gateway na seção seguinte para o recurso referenciado em `parentRefs`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-route
spec:
  parentRefs:
    - name: <gateway>
  hostnames:
    - app.example.com
  rules:
    - backendRefs:
        - name: myapp-svc
          port: 80
```

Um `PersistentVolumeClaim` pressupõe um provisionador de armazenamento já instalado; troque `storageClassName` pelo nome real da `StorageClass` do cluster de destino.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

```yaml
# Trecho do container que monta o PVC acima
containers:
  - volumeMounts:
      - name: data
        mountPath: /data
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
```

Labels organizam e identificam recursos; selectors os filtram. `matchLabels` exige correspondência exata de todos os pares chave-valor listados; `matchExpressions` aceita as condições da tabela abaixo, e um `selector` combinando os dois exige que todas sejam satisfeitas ao mesmo tempo.

```yaml
metadata:
  labels:
    app: myapp
    version: v1
    env: prod
```

```yaml
selector:
  matchLabels:
    app: myapp
    env: prod
  matchExpressions:
    - key: version
      operator: In
      values: ["v1", "v2"]
```

| Operador | Significado |
| --- | --- |
| `In` | o valor está numa lista |
| `NotIn` | o valor não está numa lista |
| `Exists` | a chave existe, o valor é ignorado |
| `DoesNotExist` | a chave não existe |

## Helm: fragmentos de values.yaml

Campos que praticamente todo chart bem-formado aceita, mesmo quando o `values.yaml` padrão do chart tem dezenas de outras opções; explore o restante do schema com `helm show values <chart>`.

Fixar `tag` explicitamente, em vez de aceitar o padrão do chart (às vezes `latest`), é o que torna a instalação reproduzível entre ambientes.

```yaml
replicaCount: 2

image:
  repository: myapp
  tag: "1.4.0"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi
```

Definir `limits.cpu` é opcional de propósito: um limite de CPU rígido demais sufoca (throttled) o processo mesmo com CPU ociosa no nó. Comece só com `requests.cpu` e adicione o limite depois de observar o consumo real.

O padrão usado pelos charts que expõem uma interface via Gateway API deixa a rota desabilitada por padrão, então instalar o chart nunca publica um serviço automaticamente:

```yaml
gateway:
  name: internal
  namespace: gateway-system
  listener: websecure
  serviceName: minha-aplicacao
  servicePort: 80

httpRoute:
  # Opt-in: habilite somente depois de revisar Gateway, hostname e acesso de rede.
  enabled: false
```

Habilitar `httpRoute.enabled: true` é uma decisão separada e explícita, feita depois de confirmar qual Gateway, listener e hostname são apropriados para aquele ambiente.

## Argo CD: fragmentos de Application

Uma Application raiz no padrão App-of-Apps observa um diretório (`directory.recurse: false`, só o primeiro nível) e cada arquivo YAML encontrado ali vira uma Application independente que o Argo CD reconcilia sozinha. `prune: false` evita que remover um arquivo do Git apague automaticamente o recurso correspondente no cluster; habilite só depois de revisar esse comportamento para o ambiente.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/cluster-config.git
    targetRevision: main
    path: gitops/applications
    directory:
      recurse: false
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Uma Application de componente, diferente da raiz, aponta para um diretório com um chart Helm local ao repositório em vez de manifests puros. Criar o namespace de destino automaticamente na primeira sincronização evita um passo manual antes de aplicar a Application.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minha-aplicacao
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/cluster-config.git
    targetRevision: main
    path: gitops/apps/categoria/minha-aplicacao
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: minha-aplicacao
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

| Campo | Papel no exemplo acima |
| --- | --- |
| `source.path` | diretório do chart Helm local ao repositório |
| `helm.valueFiles` | arquivos de valores a aplicar, relativos a `source.path` |
| `syncOptions: [CreateNamespace=true]` | cria o namespace de destino na primeira sincronização |

## Gateway API e Traefik: fragmentos

Uma `GatewayClass` é um recurso de escopo de cluster, criado uma única vez; `controllerName` identifica qual controller implementa essa classe. Confirme o valor exato na referência oficial do provider antes de fixar essa string em automação, caso o projeto renomeie o controller numa versão futura.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: traefik
spec:
  controllerName: traefik.io/gateway-controller
```

Um `Gateway` com listeners HTTP e HTTPS usa nomes de listener que precisam casar com os nomes de porta configurados no Traefik:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: internal
  namespace: gateway-system
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
    - name: websecure
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - name: internal-gateway-tls
      allowedRoutes:
        namespaces:
          from: All
```

| Listener | Porta | Protocolo |
| --- | --- | --- |
| `web` | 80 | HTTP |
| `websecure` | 443 | HTTPS |

`allowedRoutes.namespaces.from: All` permite que HTTPRoutes de qualquer namespace se associem a este Gateway; restrinja para `Same` ou uma seleção por label quando isolar por namespace for um requisito.

`certificateRefs` aponta para um `Secret` do tipo TLS que o cert-manager mantém atualizado a partir de um Certificate.

Uma `HTTPRoute` pode se associar a um listener específico em vez de a todos os listeners do Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: minha-aplicacao
  namespace: minha-aplicacao
spec:
  parentRefs:
    - name: internal
      namespace: gateway-system
      sectionName: websecure
  hostnames:
    - minha-aplicacao.internal.example.com
  rules:
    - backendRefs:
        - name: minha-aplicacao
          port: 80
```

`sectionName` associa a rota especificamente ao listener indicado, em vez de a todos os listeners do Gateway. Quando o Gateway referenciado está em outro namespace, `parentRefs[].namespace` é obrigatório; sem ele, o Traefik assume o mesmo namespace da HTTPRoute.

## Continue por aqui

[Diagnóstico de Pod, nó, certificado e Argo CD](../operacional/diagnostico-de-pod-no-cluster-e-do-argocd.md), [requests](../aprender/kubernetes/recursos/requests.md), [limits](../aprender/kubernetes/recursos/limits.md) e [QoS](../aprender/kubernetes/recursos/qos.md) explicam o que está por trás de vários desses comandos.
