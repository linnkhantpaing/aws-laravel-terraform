# Local state until bootstrap/ has created the state bucket -- see README
# "Apply order" step 2. Uncomment and fill in `bucket` with the
# `state_bucket` output from bootstrap, then re-run `terraform init`.

# terraform {
#   backend "s3" {
#     bucket       = "myapp-tfstate" # replace with your `state_bucket` output
#     key          = "prod/terraform.tfstate"
#     region       = "ap-southeast-7"
#     encrypt      = true
#     use_lockfile = true # native S3 locking, Terraform 1.10+
#   }
# }
