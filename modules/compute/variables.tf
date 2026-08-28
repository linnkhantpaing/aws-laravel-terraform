variable "name_prefix" {
  type = string
}

variable "region" {
  description = "AWS region -- used to resolve the CodeDeploy agent install bucket"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet in AZ-a"
  type        = string
}

variable "security_group_id" {
  description = "Application security group, from the security module"
  type        = string
}

variable "instance_type" {
  description = "t3.medium -- needs headroom for Nginx + PHP-FPM + Reverb + queue worker + CodeDeploy agent"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  type    = number
  default = 30
}

variable "key_name" {
  description = "EC2 key pair name. Optional -- Session Manager needs no key."
  type        = string
  default     = null
}

variable "app_bucket_arn" {
  type = string
}

variable "artifacts_bucket_arn" {
  type = string
}

variable "secret_arns" {
  description = "All Secrets Manager ARNs the app may read"
  type        = list(string)
}

variable "db_master_secret_arn" {
  description = "AWS-managed RDS master password secret"
  type        = string
}

variable "db_instance_arn" {
  description = "RDS instance ARN -- after_install.sh calls rds:DescribeDBInstances to resolve the endpoint at deploy time"
  type        = string
}

variable "kms_key_arn" {
  description = "RDS KMS key -- needed to decrypt the managed master secret"
  type        = string
}
