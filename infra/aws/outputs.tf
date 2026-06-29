output "vpc_id" {
  value = local.vpc_id
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "postgres_endpoint" {
  value = module.rds.db_instance_address
}

output "postgres_managed_secret_arn" {
  description = "RDS-managed master credentials (host/port/username/password), rotated automatically by AWS"
  value       = module.rds.db_instance_master_user_secret_arn
}

output "postgres_connection_secret_arn" {
  description = "Non-credential connection details (host/port/username/database) for ExternalSecret to merge with the password above"
  value       = aws_secretsmanager_secret.postgres_connection.arn
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_connection_secret_arn" {
  value = aws_secretsmanager_secret.redis_connection.arn
}
