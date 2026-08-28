variable "region" {
  type    = string
  default = "ap-southeast-7"
}

variable "name_prefix" {
  type    = string
  default = "myapp-prod"
}

variable "bucket_prefix" {
  description = "Globally unique S3 prefix"
  type        = string
  default     = "myapp-storage"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-southeast-7a", "ap-southeast-7b"]
}

variable "app_domain" {
  description = "Production domain, e.g. myapp.com"
  type        = string
}

variable "admin_email" {
  description = "Recipient for CloudWatch alarm notifications"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH. Narrow this once you have a static IP."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_ssh" {
  type    = bool
  default = true
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "db_engine_version" {
  type    = string
  default = "8.0.46"
}