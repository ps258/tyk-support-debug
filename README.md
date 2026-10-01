# Tyk Stack – Local Troubleshooting Scenario

Welcome! This repository deploys the **Tyk Stack** (Dashboard, Gateway and Pump) to a
local Kubernetes cluster using Helm, backed by Redis and PostgreSQL.

> **Heads up:** this deployment is **intentionally broken** in a few ways. Running the
> steps below will surface errors and failed resources — **that is expected**, and it's
> the exercise. Your task is to deploy it, work out what's wrong, and get the Tyk
> **Gateway** and **Dashboard** fully operational and talking to each other.
>
> Use **any tooling you like** — `kubectl`, the [Tyk docs](https://tyk.io/docs/),
> Google, and AI assistants (ChatGPT, Claude, Copilot, etc.). We want to see how you
> troubleshoot in a realistic environment, not test memorization.

---

## Prerequisites

Please have the following installed and working **before** we start. All three are
cross-platform (macOS, Linux, Windows).

| Tool | Purpose | Check |
|------|---------|-------|
| [minikube](https://minikube.sigs.k8s.io/docs/start/) | Local Kubernetes cluster | `minikube status` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI (pointed at minikube) | `kubectl get nodes` |
| [helm](https://helm.sh/docs/intro/install/) (v3) | Kubernetes package manager | `helm version` |

Start minikube with enough resources for the full stack (Gateway, Dashboard, Pump,
Redis and PostgreSQL):

```
minikube start
```

Notes:
- Give minikube **at least 4 CPUs / 8 GB**. Less than this and pods may sit `Pending`
  or get OOM-killed.
- Images are pulled from Docker Hub. On a shared network you can occasionally hit
  Docker Hub's anonymous pull rate limit — if you see `toomanyrequests`, wait a few
  minutes or `docker login`.
- Works on both Intel/AMD (`amd64`) and Apple Silicon / ARM (`arm64`).

---

## Quick start (optional helper scripts)

These wrap every step in the manual guide below. They are optional — the manual
commands work identically on any OS.

**macOS / Linux / WSL / Git Bash:**

```
bash deploy.sh
```

**Windows (PowerShell):**

```
./deploy.ps1
```

Then watch the pods:

```
kubectl get pods -n tyk
```

---

## Manual deployment steps

Every command below is a single line, so it pastes cleanly into any shell
(bash, zsh, PowerShell, cmd).

### 1. Add the Helm repositories

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo update
```

### 2. Install Redis and PostgreSQL

These run in the `tyk` namespace with a predefined static password.

```
helm upgrade --install tyk-redis oci://registry-1.docker.io/bitnamicharts/redis -n tyk --create-namespace --version 19.0.2 --set image.repository=bitnamilegacy/redis --set auth.password=topsecretpassword
```

```
helm upgrade --install tyk-postgres bitnami/postgresql -n tyk --create-namespace --version 12.12.10 --set image.repository=bitnamilegacy/postgresql --set auth.database=tyk_analytics --set auth.postgresPassword=topsecretpassword
```

Wait until both report `Running`:

```
kubectl get pods -n tyk
```

### 3. Install the Tyk Stack

This uses the `values.yaml` in this repository.

```
helm upgrade --install tyk-stack tyk-helm/tyk-stack -n tyk --create-namespace -f values.yaml
```

### 4. Verify the deployment

```
kubectl get pods -n tyk
```

The goal is: all Tyk pods `Running` **and** the Gateway successfully registered with
the Dashboard. If a step reports an error or a pod isn't healthy — that's the exercise.
Start digging in. 🙂

---

## Troubleshooting toolkit

Some commands that are handy while investigating (replace `<pod-name>` /
`<deployment-name>` with values from `kubectl get pods -n tyk` / `kubectl get deploy -n tyk`):

```
kubectl get pods -n tyk                                  # pod status
kubectl get jobs -n tyk                                  # any Helm hook / bootstrap jobs
kubectl get events -n tyk --sort-by=.lastTimestamp       # recent cluster events
kubectl describe pod <pod-name> -n tyk                   # events / config for one pod
kubectl logs <pod-name> -n tyk                           # logs for one pod
kubectl logs -f deploy/<deployment-name> -n tyk          # follow a deployment's logs
kubectl get svc -n tyk                                   # services (names / namespaces)
helm list -a -n tyk                                      # Helm release status
```

> Debug logging is already enabled for the Gateway and Dashboard, so the logs are
> verbose on purpose.

---

## Re-deploying after a change

As you fix issues, edit `values.yaml` and re-apply the same install command — it's
idempotent:

```
helm upgrade --install tyk-stack tyk-helm/tyk-stack -n tyk -f values.yaml
```

> 💡 **Tip:** `helm upgrade --install` re-applies changes in place, which is fine for most
> edits. If an upgrade ever errors, or a change doesn't seem to take effect, the reliable
> reset is to uninstall and reinstall — this also clears any leftover pods from a failed
> attempt:
>
> ```
> helm uninstall tyk-stack -n tyk
> helm upgrade --install tyk-stack tyk-helm/tyk-stack -n tyk --create-namespace -f values.yaml
> ```

---

## Accessing the Dashboard (optional)

Once the stack is healthy, reach the Dashboard UI via a port-forward:

```
kubectl port-forward svc/dashboard-svc-tyk-stack-tyk-dashboard 3000:3000 -n tyk
```

Then open <http://localhost:3000>.

> The exact service name depends on the Helm release name (`tyk-stack`). Confirm it
> with `kubectl get svc -n tyk`.

---

## Cleaning up

Tear everything down (removes the Tyk, Redis and PostgreSQL releases and the `tyk`
namespace) with the helper:

```
bash down.sh          # macOS / Linux / WSL / Git Bash
./down.ps1            # Windows PowerShell
```

Or do it manually:

```
helm uninstall tyk-stack tyk-redis tyk-postgres -n tyk
kubectl delete namespace tyk
```

To remove the whole cluster as well:

```
minikube delete
```
