terraform {
  # >= 1.10 because the default backend.tf (once enabled) uses use_lockfile,
  # native S3 locking introduced in 1.10 -- see backend.tf and the README.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "myapp-platform"
      Env       = "prod"
      ManagedBy = "terraform"
    }
  }
}
