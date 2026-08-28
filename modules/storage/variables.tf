variable "name_prefix" {
  description = "Prefix for resource names, e.g. myapp-prod"
  type        = string
}

variable "bucket_prefix" {
  description = "Globally unique S3 name prefix, e.g. myapp-storage"
  type        = string
}

variable "cors_allowed_origins" {
  description = "Origins allowed to upload directly to S3 via presigned URL"
  type        = list(string)
}

variable "artifact_retention_days" {
  description = "How long to keep old deployment .zip artifacts"
  type        = number
  default     = 90
}

variable "noncurrent_version_days" {
  description = "How long to keep overwritten versions of app files"
  type        = number
  default     = 180
}
