# AKD Implementation Plan

Companion to the [restructure RFC](https://github.com/NASA-IMPACT/akd-services/blob/develop/akd-restructure-rfc.md). This document maps the *current* AWS CDK infrastructure (in `akd-services`) to the *target* Helm/Kubernetes resources in this repo, and resolves/tracks the RFC's open questions.

## Resource inventory: current state vs. target

Derived from reading `akd-services/src/app.py` and its stacks directly (note: `akd-services/CLAUDE.md` describes a SearxNG/Ollama-ECS/FactReasoner/FactualityDetection service layout that no longer exists in the code — that documentation is stale).

| Current (CDK) | Target (Helm) | Notes |
|---|---|---|
| `Core` — VPC + ECS Cluster | N/A — assumes an existing k8s cluster | Out of scope for `akd-deploy`; cluster provisioning (EKS/GKE/on-prem) is a prerequisite, not a chart |
| `Database` — RDS Postgres + bootstrap Lambda | `akd-storage` (postgresql subchart + migration Job) | Lambda-based Alembic bootstrap becomes a Helm pre-upgrade hook Job |
| `Redis` — ElastiCache | `akd-storage` (redis subchart) | **Was missing from the original resource list** — used for rate limiting/caching by the API |
| `FactualityS3Bucket` | **Dropped** | Confirmed dead code — created in `app.py` but never referenced by the API (`app.py` itself has a `# TODO: should we also remove the Ollama bucket + Ollama service?` comment). Not carried into `akd-storage`. Revisit only if `factuality-standalone` is found to need artifact storage. |
| `ApiService` — Fargate + ALB + autoscaling | `akd-api` (Deployment + Service + Ingress + HPA) | |
| `BEDROCK_MODEL_ARN` env var (AWS Bedrock) | **Flagged, not yet decided** | AWS-managed-model dependency, conflicts with the cloud-agnostic goal. Recommendation: gate behind an `akd-api.bedrock.enabled` flag that is false by default outside AWS; revisit once it's clear whether Bedrock is required functionality or a leftover experiment. |
| 4 external MCP URLs (ADS Search, Code Search, Experiment Status, PDS) + keys | `akd-api` Secret values | These are third-party SaaS (`*.fastmcp.app`), not deployed by us — just secrets/config the API needs injected |
| (not in CDK) Keycloak | `akd-auth` | New — replaces `fastapi-users` local auth per the RFC |
| (not in CDK) GPU Ollama for factuality | `akd-inference` | New — toggleable, since some users already have GPU Ollama access |
| (not in CDK) factuality-standalone | `akd-factuality` | New chart, not mentioned in the RFC's repo list but required per your resource list — depends on `akd-inference` or an external Ollama URL |

## Migration steps

1. **Stand up `akd-deploy` (this repo)** with working charts for `akd-storage`, `akd-auth`, `akd-inference`, `akd-factuality` — these have no dependency on extracting `akd-api` yet, so they can be built and tested against the *existing* `akd-services` Docker image immediately.
2. **Point `akd-api` chart at the current `akd-services` image** (`ghcr.io/nasa-impact/akd-services:<tag>`) as an interim step — validates the Helm/k8s deployment path before doing the riskier repo-extraction work.
3. **Extract `src/api/` from `akd-services` into a standalone `akd-api` repo**, per the RFC's migration path. Decide the `akd-core` dependency mechanism (see below) before this step, since it determines the Dockerfile and CI changes.
4. **Re-point the `akd-api` chart's image** at the new `akd-api` repo's published image.
5. **Archive `akd-services`** with a pointer to `akd-deploy` once the new path is verified in at least one real environment.

## Open questions — resolved or tracked

- **`akd-core` dependency (submodule vs. versioned pip package):** Not resolved here — this is an `akd-api`-repo decision, not an `akd-deploy` one. Tracked as a blocker for migration step 3 above.
- **`akd-storage`: in-cluster Postgres vs. managed cloud DB:** Chart supports both via `postgresql.managed.enabled`. When `true`, the chart skips deploying the Bitnami/CNPG Postgres subchart and instead expects `postgresql.managed.secretName` (host/port/credentials) to be provided externally (e.g. via External Secrets Operator pointing at RDS-managed-secret or Cloud SQL).
- **Secrets management:** Recommend **External Secrets Operator** over Sealed Secrets — it matches the "pull in required resources dynamically" goal (e.g. point at AWS Secrets Manager in one environment, GCP Secret Manager in another, without re-encrypting anything), and it's the same mechanism the RFC already assumes for `akd-storage`'s managed-DB case. Every chart in this repo takes `*.existingSecret` values rather than inlining secret material.
- **Ingress/routing (`akd-routes`):** Not split into a separate repo for now — each chart that needs external access (`akd-api`, `akd-auth`) ships its own `Ingress` template, toggleable via `ingress.enabled`, assuming an ingress controller (nginx/Traefik) is already installed on the cluster. Revisit as a dedicated `akd-routes` chart only if shared routing logic (e.g. a single ingress with path-based routing across services) becomes necessary.
- **Monitoring (`akd-monitoring`):** Deferred, not in this initial scope.
- **S3 bucket:** Dropped — confirmed dead code, not carried forward (see table above).
- **Bedrock:** Flagged as an open question, not dropped — needs a product decision on whether it's load-bearing.

## Secrets management

Each chart exposes `*.existingSecret` (or per-key `*.existingSecret.name` / `existingSecret.key`) values instead of accepting secret material directly in `values.yaml`. Recommended flow:

1. Install [External Secrets Operator](https://external-secrets.io/) on the cluster once (not part of any AKD chart — a cluster prerequisite, like the ingress controller).
2. Per environment, commit `ExternalSecret` manifests (not in this repo's charts — add an `environments/<env>/secrets/` directory of `ExternalSecret` CRs) pointing at the cloud secret store.
3. Charts only ever reference the resulting native `Secret` objects by name.
