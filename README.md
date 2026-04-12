# k8s-microservices-demo

Orquestração de microsserviços com **Kubernetes** (Minikube), demonstrando deployment de dois serviços Spring Boot com PostgreSQL e Apache Kafka em um cluster local. Projeto de portfólio focado em infraestrutura cloud-native.

## Stack

![Java](https://img.shields.io/badge/Java-17-ED8B00?style=flat&logo=openjdk&logoColor=white)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.x-6DB33F?style=flat&logo=springboot&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Apache Kafka](https://img.shields.io/badge/Apache_Kafka-3.9-231F20?style=flat&logo=apachekafka&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?style=flat&logo=docker&logoColor=white)

## Arquitetura

```
                          Ingress (nginx)
                         /               \
          orders.microservices.local    notifications.microservices.local
                    |                              |
       order-processing-service        order-notification-service
          (Deployment + HPA)               (Deployment + HPA)
                    |                         |          |
                    +----------+   +----------+          |
                               |   |                     |
                          PostgreSQL               Apache Kafka
                          (StatefulSet)            (StatefulSet - KRaft)
                          2 databases:             2 topics:
                          - orderprocessing        - order-placed-events
                          - notificationdb         - order-cancelled-events
                                                   + DLQ topics
```

## Recursos Kubernetes

| Recurso | Descrição |
|---|---|
| `Namespace` | Isolamento em `microservices` |
| `StatefulSet` | PostgreSQL + Kafka com armazenamento persistente |
| `Deployment` | Ambos os microsserviços com rolling update |
| `HPA` | Autoscaling CPU 70% — min 1 / max 3 réplicas |
| `Service (ClusterIP)` | Comunicação interna entre serviços |
| `Service (Headless)` | DNS estável para StatefulSets |
| `Ingress (nginx)` | Roteamento externo por hostname |
| `ConfigMap` | Configuração de ambiente injetada via env vars |
| `Secret` | Credenciais do PostgreSQL em base64 |

## Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) (`winget install Kubernetes.minikube`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (incluído no Minikube)
- [order-processing-api](https://github.com/leonlimask20-dot/order-processing-api) clonado em `C:\projetos\`
- [order-notification-service](https://github.com/leonlimask20-dot/order-notification-service) clonado em `C:\projetos\`

## Como executar

### 1. Iniciar o Minikube

```powershell
minikube start --driver=docker
```

### 2. Build das imagens (dentro do daemon do Minikube)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\build-images.ps1
```

### 3. Deploy no cluster

```powershell
.\scripts\deploy.ps1
```

O script habilita o addon Ingress automaticamente e aguarda cada componente ficar pronto antes de prosseguir.

### 4. Configurar o arquivo hosts

Adicione ao `C:\Windows\System32\drivers\etc\hosts` (requer PowerShell como Administrador):

```
127.0.0.1  orders.microservices.local
127.0.0.1  notifications.microservices.local
```

### 5. Iniciar o túnel do Minikube (novo terminal, deixar aberto)

```powershell
minikube tunnel
```

### 6. Verificar status do cluster

```powershell
.\scripts\status.ps1
```

## Testando a API

### Criar pedido (order-processing)

```powershell
Invoke-RestMethod -Uri "http://orders.microservices.local/api/v1/orders" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"customerId":"cliente-01","items":[{"productId":"prod-1","productName":"Teclado","quantity":2,"unitPrice":150.00}]}'
```

**Resposta:**
```json
{
  "id": "9e5a2915-9c55-4927-8e45-bd42584c58f7",
  "customerId": "cliente-01",
  "status": "PENDING",
  "total": 300.00,
  "items": [...]
}
```

### Simular eventos Kafka (order-notification)

```powershell
# Publicar evento de pedido criado
Invoke-RestMethod -Uri "http://notifications.microservices.local/api/v1/simulate/order-placed" `
  -Method POST -ContentType "application/json" `
  -Body '{"orderId":"pedido-001","customerId":"cliente-01"}'

# Publicar evento de pedido cancelado
Invoke-RestMethod -Uri "http://notifications.microservices.local/api/v1/simulate/order-cancelled" `
  -Method POST -ContentType "application/json" `
  -Body '{"orderId":"pedido-001","customerId":"cliente-01"}'

# Listar notificações geradas
Invoke-RestMethod -Uri "http://notifications.microservices.local/api/v1/notifications" -Method GET
```

## Estrutura do repositório

```
k8s-microservices-demo/
├── k8s/
│   ├── namespace.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── postgres/
│   │   ├── secret.yaml
│   │   ├── configmap.yaml        # init.sql cria os dois bancos
│   │   ├── statefulset.yaml
│   │   └── service.yaml          # Headless
│   ├── kafka/
│   │   ├── statefulset.yaml      # KRaft mode (sem ZooKeeper)
│   │   └── service.yaml          # Headless
│   ├── order-processing/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── order-notification/
│       ├── configmap.yaml
│       ├── deployment.yaml
│       └── service.yaml
└── scripts/
    ├── build-images.ps1           # Build Docker no daemon do Minikube
    ├── deploy.ps1                 # Apply de todos os manifests em ordem
    └── status.ps1                 # Overview do cluster
```

## Conceitos demonstrados

- **Multi-stage Docker build** — imagem de produção mínima com JRE Alpine (~180MB)
- **StatefulSet vs Deployment** — StatefulSet para workloads com estado (DB, Kafka), Deployment para apps stateless
- **Headless Service** — DNS estável para pods de StatefulSets (`postgres-service`, `kafka-service`)
- **imagePullPolicy: Never** — uso de imagens locais no Minikube sem registry externo
- **ConfigMap como override** — variáveis de ambiente sobrescrevem `application.properties` do Spring Boot
- **Secret para credenciais** — senhas nunca em texto no manifest, injetadas via `secretKeyRef`
- **HPA** — Horizontal Pod Autoscaler baseado em CPU com métricas do metrics-server
- **Readiness / Liveness Probes** — Kubernetes só roteia tráfego para pods saudáveis
- **Kafka KRaft mode** — Kafka sem ZooKeeper (modo nativo desde Kafka 3.x)

## Projetos relacionados

- [order-processing-api](https://github.com/leonlimask20-dot/order-processing-api) — Clean Architecture + Spring Boot
- [order-notification-service](https://github.com/leonlimask20-dot/order-notification-service) — Apache Kafka + DLQ
