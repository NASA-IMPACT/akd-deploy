environment = "prod"
aws_region  = "us-east-1"

create_vpc          = false
vpc_id              = "REPLACE_ME" # existing EKS cluster VPC
private_subnet_ids  = ["REPLACE_ME", "REPLACE_ME"]

postgres_instance_class      = "db.t3.medium"
postgres_allocated_storage   = 50
postgres_deletion_protection = true

redis_node_type = "cache.t3.small"

eks_cluster_security_group_id = "REPLACE_ME"
