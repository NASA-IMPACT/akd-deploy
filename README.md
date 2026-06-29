# akd-deploy

Top-level Kubernetes deployment for the Accelerated Knowledge Discovery (AKD) platform, modeled after [veda-deploy](https://github.com/nasa-impact/veda-deploy).

This repo coordinates the Helm charts and configuration needed to deploy AKD to any Kubernetes cluster (AWS EKS, GCP GKE, on-prem). It does not contain application source code — that lives in the upstream repos:

| Repo | Purpose |
|---|---|
| [akd-core](https://github.com/nasa-impact/akd-core) | Agent library (the pip-installable `accelerated-discovery` package) |
| [akd-ext](https://github.com/nasa-impact/akd-ext) | User-defined agent extension module |
| [akd-services](https://github.com/NASA-IMPACT/akd-services) | The FastAPI service exposing agents behind a consolidated endpoint (to be extracted into `akd-api` per the [restructure RFC](https://github.com/NASA-IMPACT/akd-services/blob/develop/akd-restructure-rfc.md)) |
| [akd-keycloak](https://github.com/NASA-IMPACT/akd-keycloak) | Keycloak realm/config for OIDC auth |
| [factuality-standalone](https://github.com/nasa-impact/factuality-standalone) | Factuality evaluation pipeline |

See [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) for the full migration plan, resource inventory, and open decisions.

## Layout

```
akd-deploy/
  charts/
    akd-storage/      # PostgreSQL, Redis, Alembic migration Job
    akd-auth/         # Keycloak (wraps akd-keycloak realm config)
    akd-inference/    # GPU Ollama instance
    akd-factuality/   # factuality-standalone service
    akd-api/          # The FastAPI application
  environments/
    dev/values.yaml
    staging/values.yaml
    prod/values.yaml
  Makefile
```

Each chart is independently deployable and independently toggleable — e.g. an environment that already has access to a GPU Ollama instance can set `akd-inference.enabled: false` in its `values.yaml` and point `akd-factuality` at the external endpoint instead.

## Deploying

```bash
# Deploy a single service to dev
make deploy SERVICE=akd-storage ENV=dev

# Deploy everything, in dependency order (storage -> auth -> inference -> factuality -> api)
make deploy-all ENV=dev
```

`make deploy` extracts the relevant top-level key from `environments/<env>/values.yaml` via `yq` and passes it to `helm upgrade --install` for that chart.

## Deployment order

1. `akd-storage` — provision DB + Redis, run migrations
2. `akd-auth` — identity provider must be ready before the API
3. `akd-inference` — model server (optional; can point at an external GPU Ollama instead)
4. `akd-factuality` — depends on `akd-inference` (or an external Ollama URL)
5. `akd-api` — application layer

## Secrets

Secrets are **not** committed to this repo. The charts expect Kubernetes Secrets to already exist (named via `*.existingSecret` values) provisioned by [External Secrets Operator](https://external-secrets.io/) or CI-injected `kubectl create secret` calls. See [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md#secrets-management) for the recommended approach.
