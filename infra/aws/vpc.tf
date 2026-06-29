# Sandbox-only VPC creation. In the common case (create_vpc = false), the
# existing EKS cluster's VPC/subnets are used instead — see variables.tf.
module "vpc" {
  count   = var.create_vpc ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "akd-${var.environment}"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = [for i in range(2) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(2) : cidrsubnet(var.vpc_cidr, 4, i + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_id             = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
}
