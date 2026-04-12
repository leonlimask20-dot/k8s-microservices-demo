# =============================================================================
# status.ps1
# Mostra o status de todos os recursos no namespace microservices
# =============================================================================

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Status do Cluster - namespace: microservices" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "`n--- PODS ---" -ForegroundColor Yellow
kubectl get pods -n microservices -o wide

Write-Host "`n--- SERVICES ---" -ForegroundColor Yellow
kubectl get services -n microservices

Write-Host "`n--- DEPLOYMENTS ---" -ForegroundColor Yellow
kubectl get deployments -n microservices

Write-Host "`n--- HPA (Autoscaling) ---" -ForegroundColor Yellow
kubectl get hpa -n microservices

Write-Host "`n--- INGRESS ---" -ForegroundColor Yellow
kubectl get ingress -n microservices

Write-Host "`n--- STATEFULSETS ---" -ForegroundColor Yellow
kubectl get statefulsets -n microservices
