terraform {
  backend "s3" {
    bucket       = "myapp-tfstate"
    key          = "prod/terraform.tfstate"
    region       = "ap-southeast-7"
    encrypt      = true
    use_lockfile = true # native S3 locking, Terraform 1.10+
  }
}
