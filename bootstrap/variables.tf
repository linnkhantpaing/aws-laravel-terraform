variable "region" {
  description = "AWS region for all bootstrap resources"
  type        = string
  default     = "ap-southeast-7"
}

variable "prefix" {
  description = <<-EOT
    Global name prefix. S3 bucket names must be globally unique.

    Must equal envs/prod's `bucket_prefix` -- the app-deploy IAM role below
    grants access to "$${prefix}-artifacts", while envs/prod actually creates
    the bucket named "$${bucket_prefix}-artifacts". A mismatch leaves the
    deploy role pointing at a bucket that doesn't exist.
  EOT
  type        = string
  default     = "myapp-storage"
}

variable "github_owner" {
  description = "GitHub username or organization that owns the repos"
  type        = string
}

variable "infra_repo" {
  description = "Repository holding Terraform code"
  type        = string
  default     = "myapp-infra" # example -- rename to your own infra repo
}

variable "app_repo" {
  description = "Repository holding the Laravel application"
  type        = string
}
