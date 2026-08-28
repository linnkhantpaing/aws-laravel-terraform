variable "name_prefix" {
  description = "Prefix for resource names, e.g. myapp-prod"
  type        = string
}

variable "secret_path" {
  description = "Path prefix for secret names, e.g. myapp/prod"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the interface endpoint. One AZ is enough in Phase 1 (single EC2)."
  type        = list(string)
}

variable "security_group_id" {
  description = "VPC endpoint security group, from the security module"
  type        = string
}

variable "region" {
  type = string
}

variable "recovery_window_days" {
  description = "Days before a deleted secret is permanently removed. 0 = immediate."
  type        = number
  default     = 7
}
