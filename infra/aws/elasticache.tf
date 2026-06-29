resource "aws_security_group" "redis" {
  name_prefix = "akd-${var.environment}-redis-"
  description = "Allow the EKS cluster to reach ElastiCache Redis"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
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

resource "aws_elasticache_subnet_group" "redis" {
  name       = "akd-${var.environment}-redis"
  subnet_ids = local.private_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "akd-${var.environment}-redis"
  engine             = "redis"
  engine_version     = var.redis_engine_version
  node_type          = var.redis_node_type
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]
  apply_immediately  = var.environment != "prod"
}

# akd-api consumes this directly as REDIS_URL — no password (matches the
# current CDK setup, which also runs Redis without auth inside the VPC).
resource "aws_secretsmanager_secret" "redis_connection" {
  name = "akd-${var.environment}-redis-connection"
}

resource "aws_secretsmanager_secret_version" "redis_connection" {
  secret_id = aws_secretsmanager_secret.redis_connection.id
  secret_string = jsonencode({
    url = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}/0"
  })
}
