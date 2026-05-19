# k8s-microservices-demo

[![CI - Validate Kubernetes Manifests](https://github.com/leonlimask20-dot/k8s-microservices-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/leonlimask20-dot/k8s-microservices-demo/actions/workflows/ci.yml)

Microservices orchestration with **Kubernetes** (Minikube), demonstrating the
deployment of two Spring Boot services with PostgreSQL and Apache Kafka on a
local cluster. Portfolio project focused on cloud-native infrastructure.

## Stack

![Java](https://img.shields.io/badge/Java-17-ED8B00?style=flat&logo=openjdk&logoColor=white)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.x-6DB33F?style=flat&logo=springboot&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Apache Kafka](https://img.shields.io/badge/Apache_Kafka-3.9-231F20?style=flat&logo=apachekafka&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?style=flat&logo=docker&logoColor=white)

## Architecture

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

## Kubernetes resources

| Resource | Description |
|---|---|
| `Namespace` | Isolation in `microservices` |
| `StatefulSet` | PostgreSQL + Kafka with persistent storage |
| `Deployment` | Both microservices with rolling update |
| `HPA` | CPU autoscaling at 70% — min 1 / max 3 replicas |
| `Service (ClusterIP)` | Internal communication between services |
| `Service (Headless)` | Stable DNS for StatefulSets |
| `Ingress (nginx)` | External routing by hostname |
| `ConfigMap` | Environment configuration injected via env vars |
| `Secret` | PostgreSQL credentials in base64 |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) (`winget install Kubernetes.minikube`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (included with Minikube)
- [order-processing-api](https://github.com/leonlimask20-dot/order-processing-api) cloned into `C:\projetos\`
- [order-notification-service](https://github.com/leonlimask20-dot/order-notification-service) cloned into `C:\projetos\`

## How to run

### 1. Start Minikube

```powershell
minikube start --driver=docker
```

### 2. Build the images (inside the Minikube daemon)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\build-images.ps1
```

### 3. Deploy to the cluster

```powershell
.\scripts\deploy.ps1
```

The script enables the Ingress addon automatically and waits for each component
to become ready before proceeding.

### 4. Configure the hosts file

Add to `C:\Windows\System32\drivers\etc\hosts` (requires PowerShell as Administrator):

```
127.0.0.1  orders.microservices.local
127.0.0.1  notifications.microservices.local
```

### 5. Start the Minikube tunnel (new terminal, keep it open)

```powershell
minikube tunnel
```

### 6. Check the cluster status

```powershell
.\scripts\status.ps1
```

## Testing the API

### Create order (order-processing)

```powershell
Invoke-RestMethod -Uri "http://orders.microservices.local/api/v1/orders" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"customerId":"customer-01","items":[{"productId":"prod-1","productName":"Keyboard","quantity":2,"unitPrice":150.00}]}'
```

**Response:**
```json
{
  "id": "9e5a2915-9c55-4927-8e45-bd42584c58f7",
  "customerId": "customer-01",
  "status": "PENDING",
  "total": 300.00,
  "items": [...]
}
```

### Simulate Kafka events (order-notification)

```powershell
# Publish an order-placed event
Invoke-RestMethod -Uri "http://notifications.microservices.local/api/v1/simulate/order-placed" `
  -Method POST -ContentType "application/json" `
  -Body '{"orderId":"order-001","customerId":"customer-01"}'

# Publish an order-cancelled event
Invoke-RestMethod -Uri "http://notifications.microservices.local/api/v1/simulate/order-cancelled" `
  -Method POST -ContentType "application/json" `
  -Body '{"orderId":"order-001","customerId":"customer-01"}'

# List the generated notifications
Invoke-RestMethod -Uri "http://notifications.microservices.local/api/v1/notifications" -Method GET
```

## Repository structure

```
k8s-microservices-demo/
├── k8s/
│   ├── namespace.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── postgres/
│   │   ├── secret.yaml
│   │   ├── configmap.yaml        # init.sql creates both databases
│   │   ├── statefulset.yaml
│   │   └── service.yaml          # Headless
│   ├── kafka/
│   │   ├── statefulset.yaml      # KRaft mode (no ZooKeeper)
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
    ├── build-images.ps1           # Build Docker images in the Minikube daemon
    ├── deploy.ps1                 # Apply all manifests in order
    └── status.ps1                 # Cluster overview
```

## Concepts demonstrated

- **Multi-stage Docker build** — minimal production image with Alpine JRE (~180MB)
- **StatefulSet vs Deployment** — StatefulSet for stateful workloads (DB, Kafka), Deployment for stateless apps
- **Headless Service** — stable DNS for StatefulSet pods (`postgres-service`, `kafka-service`)
- **imagePullPolicy: Never** — using local images in Minikube without an external registry
- **ConfigMap as override** — environment variables override Spring Boot's `application.properties`
- **Secret for credentials** — passwords never in plain text in the manifest, injected via `secretKeyRef`
- **HPA** — Horizontal Pod Autoscaler based on CPU with metrics-server
- **Readiness / Liveness Probes** — Kubernetes only routes traffic to healthy pods
- **Kafka KRaft mode** — Kafka without ZooKeeper (native mode since Kafka 3.x)

## 🤖 Agent Architecture

This project was built and code-reviewed using a **multi-agent
context-optimization workflow**: specialized AI agents each audit a single
slice of the codebase — manifests, probes, scaling, secrets — within a strict
context budget. The approach cuts review time and token cost while keeping full
traceability of every finding.

Methodology, agent templates and the full playbook: **[leonlim3.gumroad.com](https://leonlim3.gumroad.com)**

## Related projects

- [order-processing-api](https://github.com/leonlimask20-dot/order-processing-api) — Clean Architecture + Spring Boot
- [order-notification-service](https://github.com/leonlimask20-dot/order-notification-service) — Apache Kafka + DLQ
