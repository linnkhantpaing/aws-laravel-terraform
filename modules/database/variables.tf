variable "name_prefix" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets, both AZs. RDS requires 2+ even for Single-AZ."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS subnet groups require subnets in at least two availability zones."
  }
}

variable "security_group_id" {
  description = "RDS security group, from the security module"
  type        = string
}

variable "instance_class" {
  description = "db.t4g.small (2GB) recommended over micro for a live-payments system"
  type        = string
  default     = "db.t4g.small"
}

variable "engine_version" {
  description = "MySQL 8.x. Pin the minor version to avoid surprise upgrades."
  type        = string
  default     = "8.0.46"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling. 0 disables autoscaling."
  type        = number
  default     = 100
}

variable "database_name" {
  type    = string
  default = "myapp"
}

variable "master_username" {
  type    = string
  default = "myapp_admin"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "backup_window" {
  description = "UTC. Default is 00:30-01:30, chosen for a UTC+6:30 local timezone."
  type        = string
  default     = "18:00-19:00"
}

variable "maintenance_window" {
  type    = string
  default = "sun:19:30-sun:20:30"
}

variable "deletion_protection" {
  type    = bool
  default = true
}
