terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Bootstrap uses LOCAL state on purpose -- it creates the bucket that every
  # other stack stores its state in. Chicken and egg.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "myapp-platform"
      Env       = "prod"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}
