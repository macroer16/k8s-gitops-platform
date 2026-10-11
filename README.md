# Kubernetes GitOps platform

[![End-to-end](https://github.com/macroer16/k8s-gitops-platform/actions/workflows/e2e.yml/badge.svg)](https://github.com/macroer16/k8s-gitops-platform/actions/workflows/e2e.yml)
[![Static checks](https://github.com/macroer16/k8s-gitops-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/macroer16/k8s-gitops-platform/actions/workflows/ci.yml)
[![Images](https://github.com/macroer16/k8s-gitops-platform/actions/workflows/images.yml/badge.svg)](https://github.com/macroer16/k8s-gitops-platform/actions/workflows/images.yml)

A production-style Kubernetes platform that I built and run on my own laptop, managed entirely through Git with ArgoCD. It runs my full-stack app, [Due](https://github.com/macroer16/uni-deadline-tracker-api) (React, FastAPI, PostgreSQL), with supply-chain security, admission policies, network isolation, HTTPS, autoscaling and monitoring.

Every push spins up a fresh 3-node cluster in GitHub Actions, installs the whole platform from scratch the same way I do locally, and tests it: the app works, unsafe workloads are refused, the database is isolated, and the API scales under load. It costs £0.

These screenshots are taken automatically by the latest successful CI run on a brand-new cluster. The full test output is on the [`e2e-results` branch](https://github.com/macroer16/k8s-gitops-platform/tree/e2e-results).

| ArgoCD: every component installed from Git, Synced and Healthy | The app's resources as ArgoCD sees them |
|---|---|
| ![ArgoCD applications, all Synced and Healthy](https://raw.githubusercontent.com/macroer16/k8s-gitops-platform/e2e-results/argocd-apps.png) | ![ArgoCD resource tree for the due app](https://raw.githubusercontent.com/macroer16/k8s-gitops-platform/e2e-results/argocd-due-tree.png) |
| **The app running on the platform, over HTTPS through the Gateway** | **Grafana during the load test: traffic, latency and autoscaling** |
| ![The Due web app](https://raw.githubusercontent.com/macroer16/k8s-gitops-platform/e2e-results/due-app.png) | ![Grafana dashboard for the API](https://raw.githubusercontent.com/macroer16/k8s-gitops-platform/e2e-results/grafana-due.png) |

## What's in it

| Area | Tools | What it does |
|---|---|---|
| GitOps | **ArgoCD** (app of apps, sync waves) | Git is the source of truth. One root Application installs 9 others in dependency order and keeps the cluster matching Git, undoing manual changes (self-heal). |
| Traffic | **Gateway API + Envoy Gateway** | One shared HTTPS gateway with `HTTPRoute`s per app, HTTP→HTTPS redirect and rate limits (a much tighter one on logins). I used the Gateway API because ingress-nginx was retired in March 2026. |
| TLS | **cert-manager** | Creates a private certificate authority for the cluster and issues and renews the gateway's certificate. |
| Supply chain | **Cosign** (keyless) + **Trivy** + **SBOM** | CI scans images for vulnerabilities, then signs them with a short-lived certificate tied to this repo's workflow. No signing keys exist anywhere. An SPDX SBOM is attached as a signed attestation. |
| Admission control | **Kyverno** + **Pod Security Admission** | In the app namespace the cluster refuses unsigned images, unapproved registries, `:latest` tags, missing resource limits and missing readiness probes. Pod Security `restricted` refuses root, privilege escalation and extra Linux capabilities. |
| Secrets | **Sealed Secrets** | Secrets are encrypted with the cluster's public key before they go into Git, so they're safe to commit. Only the controller in the cluster can decrypt them. |
| Network | **NetworkPolicies** | Default deny. The database only accepts the API; the API only accepts the gateway, the web pods and Prometheus. |
| Scaling | **HPA** + **metrics-server** + **PodDisruptionBudgets** | The API scales from 2 to 6 pods on CPU, with rolling updates that never drop below one ready pod. |
| Observability | **Prometheus, Grafana, Alertmanager** | The app exposes metrics; a Grafana dashboard shows traffic, errors, latency and autoscaling. Alerts cover the API being down, high error rates, slow responses, sustained maximum scaling, and a spike in failed logins (possible password guessing). |
| Testing | **kind**, **k6**, **kubeconform**, **Kyverno CLI**, **ShellCheck** | Static checks on every push; full end-to-end tests on a real cluster. |

## Architecture

```
                         ┌──────────────────────── Kubernetes cluster ───────────────────────────┐
  browser ──HTTPS──▶ Envoy Gateway ──/api──▶ due-api (2–6 pods, HPA) ──▶ due-postgres (StatefulSet)
                     │  TLS: cert-manager      ▲  /metrics                   ▲ only from due-api
                     │  rate limits            │                             │ (NetworkPolicy)
                     └──/───▶ due-web (nginx, non-root, read-only filesystem)
                                               │
                         Prometheus ◀──scrape──┘ ──▶ Grafana dashboards, Alertmanager rules
                         Kyverno + Pod Security: check every pod before it's admitted
                         Sealed Secrets: decrypt committed secrets inside the cluster
                         ArgoCD: keeps all of the above matching Git
                         └────────────────────────────────────────────────────────────────────┘
       ▲ watches main                                                     ▲ pulls signed images
  GitHub repo (charts, values, policies)                    GitHub Container Registry (ghcr.io)
       ▲ git push                                                         ▲ build → Trivy → Cosign sign
       me                                                       Actions: images.yml
```

### How a change reaches the cluster

1. **App release:** I set `appVersion` in `charts/due/Chart.yaml` to a commit of the app repo and push.
2. `images.yml` builds the API and web images at that commit, **scans** them with Trivy (stopping on fixable critical vulnerabilities), pushes them to `ghcr.io`, **signs** them with Cosign using GitHub's OIDC identity, and attaches a signed **SBOM**.
3. **ArgoCD** sees the new commit and rolls the app out.
4. When the new pods are created, **Kyverno** checks each image's signature against this repo's workflow identity and replaces the tag with the exact digest it checked. An image built anywhere else is refused.
5. Readiness probes and the PodDisruptionBudget keep the app up during the rollout.

The release is a normal commit, so the Git history shows exactly what ran and when, and rolling back is `git revert`.

## Run it yourself

You need Docker and 8 GB of free RAM (16 GB is more comfortable). On Windows, use WSL2 with Docker Desktop.

```bash
make tools        # installs kubectl, helm, k3d and kubeseal (pinned versions) into ~/.local/bin
make up           # creates a 3-node k3d cluster, installs ArgoCD, which installs everything else (~10 min)
```

Then open:

- **App:** https://due.localhost
- **ArgoCD:** https://argocd.localhost (user `admin`, password from `make argocd-password`)
- **Grafana:** https://grafana.localhost (user `admin`, password from `make grafana-password`)

Your browser will warn about the certificate, because it's signed by the cluster's own certificate authority.

The first `make up` generates the app's secrets, seals them, and writes `secrets/local/*.yaml`. Commit those so ArgoCD manages them. The controller's private key is backed up to `~/.config/k8s-gitops-platform/` so a rebuilt cluster can still decrypt them.

```bash
make policy-test  # shows each unsafe workload being refused
make loadtest     # k6 load test from inside the cluster; watch the API scale up
make down         # delete the cluster
```

## What CI proves on every push

**Static checks** (`ci.yml`):
- `helm lint`, then every chart rendered with each cluster's values and validated with **kubeconform** against Kubernetes and CRD schemas.
- **Kyverno CLI:** my own app chart must pass my own policies before it gets anywhere near a cluster.
- **Trivy** misconfiguration scan of the charts, and **ShellCheck** on the scripts.

**End to end** (`e2e.yml`), on a fresh 3-node kind cluster:
1. Builds the app images, pushes them to a local registry, and signs them with Cosign. It also pushes one image *unsigned* on purpose.
2. Runs `scripts/bootstrap.sh`, the same script used locally, and waits for all ArgoCD applications to be Synced and Healthy.
3. **Smoke tests** through the gateway: HTTPS, security headers, register, log in, create and list deadlines, the calendar feed, and 401 without a token.
4. **Policy tests:** each of these must be refused: an unsigned image, an unapproved registry, `:latest`, no limits, root, privilege escalation, and no readiness probe. A pod in another namespace must **not** reach the database, while the API must.
5. **Load test** (k6, about 40 virtual users): p95 latency under 800 ms, and the autoscaler adds API pods.
6. Takes screenshots of the app, ArgoCD and Grafana, and uploads them as artifacts.

## Repository layout

```
charts/
  platform-apps/     app of apps: one ArgoCD Application per component, versions pinned
    values-local.yaml / values-ci.yaml   per-cluster differences
  platform-config/   Gateway, TLS chain, Kyverno policies, routes to ArgoCD and Grafana
  due/               the app: API, web, Postgres, HPA, PDBs, NetworkPolicies, routes,
                     rate limits, ServiceMonitor, alert rules, Grafana dashboard
cluster/             k3d and kind configs, ArgoCD values, the root Application
scripts/             install-tools, up, bootstrap, make-secrets, wait-healthy, down
secrets/local/       SealedSecrets for my local cluster (encrypted, safe to commit)
tests/               smoke, policy and load tests; CI screenshot script
.github/workflows/   ci.yml, images.yml, e2e.yml
```

## Design decisions

- **App of apps with sync waves**, rather than one huge chart. Each component is its own ArgoCD Application, so it can be synced, debugged or rolled back on its own. The waves stop the app from installing before the CRDs and controllers it needs exist.
- **Keyless signing** rather than a Cosign key pair. A stored signing key is one more secret to leak. With keyless signing, the "key" is the identity of this repo's GitHub Actions workflow, and every signature is recorded in the public Rekor log.
- **Two layers of admission control.** Pod Security Admission is built in and handles the basics (root, privilege escalation, capabilities). Kyverno adds the rules it can't express: signatures, registries, tags, limits and probes.
- **The CI cluster uses the real bootstrap script.** If the platform installs in CI, it installs the same way on my laptop.
- **Everything pinned.** Chart versions, tool versions, and image digests at admission time.

## Problems I hit (and how I fixed them)

_TODO: in my own words, after running it myself._

## What I learned

_TODO: in my own words._

## Limitations and next steps

- It runs locally and in CI, not on a public cloud, because I'm keeping this free. The charts are cloud-agnostic; the next step is a small managed cluster (for example AKS on Azure for Students) with a real domain and Let's Encrypt.
- Rate limits are per gateway replica (local), not per client IP. Per-IP limits need Envoy's global rate limiting with Redis.
- PostgreSQL is a single pod with a volume: no replicas and no backups yet. In production I'd use a managed database or CloudNativePG with scheduled backups.
- Alertmanager has no receiver configured, so alerts are visible but not sent anywhere.

Licensed under MIT.
