# =============================================================================
# deploy.ps1
# Aplica todos os manifests Kubernetes no Minikube na ordem correta:
#   namespace → secrets/configs → banco/kafka → apps → ingress/hpa
# =============================================================================

$ErrorActionPreference = "Stop"
$K8S = "$PSScriptRoot\..\k8s"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Deploy no Minikube - k8s-microservices-demo" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Namespace
Write-Host "`n[1/7] Criando namespace..." -ForegroundColor Yellow
kubectl apply -f "$K8S\namespace.yaml"

# 2. Secrets e ConfigMaps (infra)
Write-Host "`n[2/7] Aplicando Secrets e ConfigMaps de infraestrutura..." -ForegroundColor Yellow
kubectl apply -f "$K8S\postgres\secret.yaml"
kubectl apply -f "$K8S\postgres\configmap.yaml"

# 3. PostgreSQL (StatefulSet + Service)
Write-Host "`n[3/7] Implantando PostgreSQL..." -ForegroundColor Yellow
kubectl apply -f "$K8S\postgres\statefulset.yaml"
kubectl apply -f "$K8S\postgres\service.yaml"

Write-Host "Aguardando PostgreSQL ficar pronto..." -ForegroundColor Yellow
kubectl rollout status statefulset/postgres -n microservices --timeout=120s

# 4. Kafka (StatefulSet + Service)
Write-Host "`n[4/7] Implantando Kafka..." -ForegroundColor Yellow
kubectl apply -f "$K8S\kafka\statefulset.yaml"
kubectl apply -f "$K8S\kafka\service.yaml"

Write-Host "Aguardando Kafka ficar pronto..." -ForegroundColor Yellow
kubectl rollout status statefulset/kafka -n microservices --timeout=120s

# 5. Microserviços: ConfigMaps + Deployments + Services
Write-Host "`n[5/7] Implantando microserviços..." -ForegroundColor Yellow
kubectl apply -f "$K8S\order-processing\configmap.yaml"
kubectl apply -f "$K8S\order-processing\deployment.yaml"
kubectl apply -f "$K8S\order-processing\service.yaml"

kubectl apply -f "$K8S\order-notification\configmap.yaml"
kubectl apply -f "$K8S\order-notification\deployment.yaml"
kubectl apply -f "$K8S\order-notification\service.yaml"

# 6. Ingress (habilita addon se necessário) + HPA
Write-Host "`n[6/7] Habilitando Ingress e HPA..." -ForegroundColor Yellow
$addons = minikube addons list 2>&1
if ($addons -match "ingress\s+\|\s+enabled") {
    Write-Host "Addon ingress já está habilitado." -ForegroundColor Green
} else {
    Write-Host "Habilitando addon ingress..." -ForegroundColor Yellow
    minikube addons enable ingress
}
kubectl apply -f "$K8S\ingress.yaml"
kubectl apply -f "$K8S\hpa.yaml"

# 7. Status final
Write-Host "`n[7/7] Status dos pods..." -ForegroundColor Yellow
kubectl get pods -n microservices

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " Deploy concluído!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Exibe o IP do Minikube para configurar o hosts
$minikubeIp = minikube ip
Write-Host "`nAdicione as seguintes linhas ao arquivo hosts:" -ForegroundColor White
Write-Host "  $minikubeIp  orders.microservices.local" -ForegroundColor Yellow
Write-Host "  $minikubeIp  notifications.microservices.local" -ForegroundColor Yellow
Write-Host "`nArquivo hosts: C:\Windows\System32\drivers\etc\hosts" -ForegroundColor White
Write-Host "(requer PowerShell como Administrador para editar)" -ForegroundColor Gray
