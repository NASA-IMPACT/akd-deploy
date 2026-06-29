provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AcceleratedKnowledgeDiscovery"
      Environment = var.environment
      ManagedBy   = "terraform/akd-deploy"
    }
  }
}
