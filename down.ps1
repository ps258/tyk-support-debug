<#
  down.ps1 - tear down the troubleshooting scenario on Windows (PowerShell): remove the
  Tyk Stack, Redis and PostgreSQL Helm releases and delete the `tyk` namespace.

  Usage:   ./down.ps1

  Safe to run repeatedly; anything already gone is skipped. The minikube cluster itself is
  left running (to remove it entirely: `minikube delete`).
#>

$ErrorActionPreference = "Continue"
$Namespace = "tyk"

function Info($msg) { Write-Host "`n==> $msg" -ForegroundColor Blue }

foreach ($bin in @("helm", "kubectl")) {
  if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) {
    Write-Error "'$bin' not found on your PATH."; exit 1
  }
}

Info "Uninstalling Helm releases in namespace '$Namespace'"
foreach ($release in @("tyk-stack", "tyk-redis", "tyk-postgres")) {
  helm uninstall $release -n $Namespace 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Host "  uninstalled: $release" }
  else { Write-Host "  skipped (not found): $release" }
}

Info "Deleting namespace '$Namespace'"
kubectl delete namespace $Namespace --ignore-not-found

Info "Done. The minikube cluster is still running."
Write-Host "    To remove the cluster entirely: minikube delete"
