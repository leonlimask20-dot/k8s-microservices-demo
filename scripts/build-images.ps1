# =============================================================================
# build-images.ps1
# Aponta o Docker para o daemon do Minikube e constrói as imagens dos dois
# microserviços. As imagens ficam disponíveis diretamente para o Kubernetes.
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Build de Imagens Docker para Minikube" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Verifica se o Minikube está rodando
Write-Host "`n[1/4] Verificando status do Minikube..." -ForegroundColor Yellow
$status = minikube status --format='{{.Host}}' 2>&1
if ($status -ne "Running") {
    Write-Host "Minikube não está rodando. Iniciando..." -ForegroundColor Yellow
    minikube start --driver=docker
}
Write-Host "Minikube está rodando." -ForegroundColor Green

# 2. Aponta o Docker CLI para o daemon do Minikube
Write-Host "`n[2/4] Apontando Docker para o daemon do Minikube..." -ForegroundColor Yellow
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
Write-Host "Docker apontado para Minikube." -ForegroundColor Green

# 3. Build da imagem order-processing-service
Write-Host "`n[3/4] Construindo imagem: order-processing-service:latest..." -ForegroundColor Yellow
$orderProcessingPath = "C:\projetos\order-processing-api"
if (-Not (Test-Path $orderProcessingPath)) {
    Write-Error "Diretório não encontrado: $orderProcessingPath"
}
docker build -t order-processing-service:latest $orderProcessingPath
Write-Host "Imagem order-processing-service:latest criada com sucesso." -ForegroundColor Green

# 4. Build da imagem order-notification-service
Write-Host "`n[4/4] Construindo imagem: order-notification-service:latest..." -ForegroundColor Yellow
$orderNotificationPath = "C:\projetos\order-notification-service"
if (-Not (Test-Path $orderNotificationPath)) {
    Write-Error "Diretório não encontrado: $orderNotificationPath"
}
docker build -t order-notification-service:latest $orderNotificationPath
Write-Host "Imagem order-notification-service:latest criada com sucesso." -ForegroundColor Green

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " Imagens construídas com sucesso!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "`nPróximo passo: execute scripts\deploy.ps1" -ForegroundColor White
