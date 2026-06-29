environment = "dev"
aws_region  = "us-east-1"

create_vpc = true # sandbox: no pre-existing EKS cluster VPC to attach to yet

postgres_instance_class    = "db.t3.small"
postgres_allocated_storage = 20
postgres_deletion_protection = false

redis_node_type = "cache.t3.micro"

# Fill in once the dev EKS cluster exists:
eks_cluster_security_group_id = "REPLACE_ME"
