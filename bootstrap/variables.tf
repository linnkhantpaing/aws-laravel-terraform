variable "region" {
  description = "AWS region for all bootstrap resources"
  type        = string
  default     = "ap-southeast-7"
}

variable "prefix" {
  description = "Global name prefix. S3 bucket names must be globally unique."
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
  default     = "ai-academy-infra"
}

variable "app_repo" {
  description = "Repository holding the Laravel application"
  type        = string
}
