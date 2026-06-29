# infra/aws

Terraform for the AWS-managed resources that `akd-storage` can consume in "managed" mode: RDS Postgres and ElastiCache Redis. Other cloud providers will live as siblings (`infra/gcp/`, `infra/on-prem/`) once needed — same `terraform init/plan/apply` workflow regardless of which one you're in.

## What this does and does not do

- **Does:** provision an RDS Postgres instance and an ElastiCache Redis cluster into an existing (or, for sandboxes, newly created) VPC, and publish their connection details to AWS Secrets Manager.
- **Does not:** run Alembic migrations, deploy the API, or touch Kubernetes at all. Migrations and app deployment are handled by the `akd-storage`/`akd-api` Helm charts — see [the root IMPLEMENTATION_PLAN.md](../../IMPLEMENTATION_PLAN.md) for why that split exists, and the note below on rollback semantics.
- **Does not** create the EKS (or other) Kubernetes cluster — that's assumed to already exist (`var.vpc_id` / `var.private_subnet_ids` / `var.eks_cluster_security_group_id` point at it).

## Usage

```bash
cd infra/aws
terraform init -backend-config=environments/dev.backend.hcl
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

Each environment gets its own state file (`environments/<env>.backend.hcl`) and variable set (`environments/<env>.tfvars`). Fill in the `REPLACE_ME` placeholders in both before running — they're deliberately left blank rather than guessed, since they depend on your actual AWS account (state bucket name, existing VPC/subnet IDs, EKS node security group).

## Handing connection details to Kubernetes

This module never writes credentials into Terraform state in plaintext — RDS's master password is created and rotated by AWS itself (`manage_master_user_password = true`), and both Postgres and Redis connection info land in Secrets Manager (see `outputs.tf`).

Getting them into the cluster as Kubernetes Secrets is External Secrets Operator's job, not Terraform's — see the example `ExternalSecret` manifests in `environments/prod/secrets/`. Order of operations for standing up a managed environment:

1. `terraform apply` here → creates the RDS/ElastiCache instances + Secrets Manager entries
2. Apply the environment's `ExternalSecret` manifests (`environments/<env>/secrets/*.yaml`) → syncs them into the cluster as native Secrets
3. `make deploy SERVICE=akd-storage ENV=<env>` with `postgresql.managed.enabled` / `redis.managed.enabled` set → `akd-storage` skips the in-cluster subcharts and the migration Job connects straight to RDS

## Why migrations aren't run here

It might seem natural to run `alembic upgrade head` as a Terraform `null_resource` provisioner here, with the idea that a failed `terraform apply` rolls it back. That doesn't actually work the way CDK's `BootstrappedDb` construct did: CloudFormation has an atomic rollback model built into the deployment engine — if any resource in a stack update fails, CloudFormation automatically reverts every resource in that update, including custom resources backed by Lambda. **Terraform has no equivalent.** A failed `apply` simply halts; whatever already succeeded stays applied, and there's no automatic "undo" of a `null_resource` provisioner's side effects.

So migrations stay out of Terraform entirely and live in the Helm release lifecycle instead (`akd-storage`'s migration Job, a Helm pre-upgrade hook) — see the root README's "Deployment order" and the rollback discussion that follows it for how that's made safe.
