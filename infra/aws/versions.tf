terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    # Configured per-environment at `terraform init`, e.g.:
    #   terraform init -backend-config=environments/dev.backend.hcl
    # See README.md for the expected backend config keys.
  }
}
