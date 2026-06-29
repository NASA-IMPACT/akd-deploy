resource "aws_security_group" "postgres" {
  name_prefix = "akd-${var.environment}-postgres-"
  description = "Allow the EKS cluster to reach RDS Postgres"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "akd-${var.environment}"

  engine                = "postgres"
  engine_version        = var.postgres_engine_version
  family                = "postgres${split(".", var.postgres_engine_version)[0]}"
  instance_class        = var.postgres_instance_class
  allocated_storage     = var.postgres_allocated_storage
  max_allocated_storage = var.postgres_allocated_storage * 5

  db_name  = var.postgres_db_name
  username = var.postgres_username
  port     = 5432

  # RDS creates and rotates the master password in Secrets Manager for us —
  # no password ever passes through Terraform state in plaintext.
  manage_master_user_password = true

  vpc_security_group_ids = [aws_security_group.postgres.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name

  multi_az            = var.environment == "prod"
  deletion_protection = var.postgres_deletion_protection
  skip_final_snapshot = var.environment != "prod"

  backup_retention_period = var.environment == "prod" ? 7 : 1

  create_monitoring_role = false
}

resource "aws_db_subnet_group" "postgres" {
  name       = "akd-${var.environment}-postgres"
  subnet_ids = local.private_subnet_ids
}

# Mirror the RDS-managed secret into a predictable name/shape so External
# Secrets Operator can sync it into the cluster as the Secret that
# akd-storage's `postgresql.managed.existingSecret` expects (host, port,
# username, password, database).
resource "aws_secretsmanager_secret" "postgres_connection" {
  name = "akd-${var.environment}-postgres-connection"
}

resource "aws_secretsmanager_secret_version" "postgres_connection" {
  secret_id = aws_secretsmanager_secret.postgres_connection.id
  secret_string = jsonencode({
    host     = module.rds.db_instance_address
    port     = 5432
    username = var.postgres_username
    database = var.postgres_db_name
    # password is intentionally omitted here — pulled directly from the
    # RDS-managed secret (module.rds.db_instance_master_user_secret_arn) by
    # the ExternalSecret resource, not duplicated through Terraform state.
  })
}
