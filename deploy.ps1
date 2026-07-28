<#
  deploy.ps1 - set up the troubleshooting scenario on Windows (PowerShell): install
  Redis, PostgreSQL and the (intentionally broken) Tyk Stack into the `tyk` namespace.

  Usage:   ./deploy.ps1

  Requires: minikube (running), kubectl (pointed at minikube) and helm (v3) on your PATH.

  NOTE: the Tyk Stack install is EXPECTED to surface errors - that's the exercise.
#>

$ErrorActionPreference = "Stop"
$Namespace  = "tyk"
$ValuesFile = Join-Path $PSScriptRoot "values.yaml"

function Info($msg) { Write-Host "`n==> $msg" -ForegroundColor Blue }
function Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

Info "Checking prerequisites"
foreach ($bin in @("kubectl", "helm")) {
  if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) {
    Write-Error "'$bin' not found on your PATH. Please install it and retry."
    exit 1
  }
}

Info "Adding Helm repositories"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo update

Info "Installing Redis (release: tyk-redis)"
helm upgrade --install tyk-redis oci://registry-1.docker.io/bitnamicharts/redis -n $Namespace --create-namespace --version 19.0.2 --set image.repository=bitnamilegacy/redis --set auth.password=topsecretpassword

Info "Installing PostgreSQL (release: tyk-postgres)"
helm upgrade --install tyk-postgres bitnami/postgresql -n $Namespace --create-namespace --version 12.12.10 --set image.repository=bitnamilegacy/postgresql --set auth.database=tyk_analytics --set auth.postgresPassword=topsecretpassword

Info "Installing the Tyk Stack (release: tyk-stack)"
# Don't abort the script if this reports an error - a broken deploy is the exercise.
$ErrorActionPreference = "Continue"
helm upgrade --install tyk-stack tyk-helm/tyk-stack -n $Namespace --create-namespace -f $ValuesFile
if ($LASTEXITCODE -ne 0) {
  Warn "The Tyk Stack install reported an error - this is expected for the exercise."
  Warn "Investigate with the commands below; fix values.yaml and re-run this script."
}

Info "Scenario deployed. Current state:"
kubectl get pods -n $Namespace

Write-Host @"

Next steps:
  kubectl get pods -n $Namespace
  kubectl get events -n $Namespace --sort-by=.lastTimestamp
  kubectl logs <pod-name> -n $Namespace

If a release gets stuck, reset it with:
  helm uninstall tyk-stack -n $Namespace
"@
