variable "environment" {
  description = "Environment name (dev, staging, prod) — must match environments/<env>/values.yaml in the Helm side of this repo"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# --- Networking ---
# By default this expects an EKS (or other k8s) cluster's VPC to already exist —
# RDS/ElastiCache need to live in the same VPC as the cluster to be reachable.
# Set create_vpc = true only for a standalone sandbox with no existing cluster VPC.

variable "create_vpc" {
  description = "If true, create a new VPC instead of using an existing one (sandbox/demo use only)"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "Existing VPC ID to deploy RDS/ElastiCache into (required unless create_vpc = true)"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs for RDS/ElastiCache (required unless create_vpc = true)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block, only used when create_vpc = true"
  type        = string
  default     = "10.20.0.0/16"
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS node group / cluster, granted ingress to RDS (5432) and Redis (6379)"
  type        = string
}

# --- PostgreSQL (RDS) ---

variable "postgres_engine_version" {
  type    = string
  default = "17"
}

variable "postgres_instance_class" {
  type    = string
  default = "db.t3.small" # mirrors BURSTABLE3/SMALL from the current CDK stack
}

variable "postgres_allocated_storage" {
  type    = number
  default = 20
}

variable "postgres_db_name" {
  type    = string
  default = "akd_data"
}

variable "postgres_username" {
  type    = string
  default = "akd_user"
}

variable "postgres_deletion_protection" {
  type    = bool
  default = false
}

# --- Redis (ElastiCache) ---

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}
