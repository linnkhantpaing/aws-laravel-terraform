# Local state until bootstrap/ has created the state bucket -- see README
# "Apply order" step 2. Uncomment and fill in `bucket` with the
# `state_bucket` output from bootstrap, then re-run `terraform init`.
#
# Backend blocks cannot reference variables, so `region` below is a literal
# value -- if you change var.region in variables.tf, update it here too.

# terraform {
#   backend "s3" {
#     bucket       = "myapp-tfstate" # replace with your `state_bucket` output
#     key          = "prod/terraform.tfstate"
#     region       = "ap-southeast-7" # must match var.region
#     encrypt      = true
#     use_lockfile = true # native S3 locking, Terraform 1.10+
#   }
# }
