variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_ssh" {
  description = "Open port 22. Set false once Session Manager is verified working."
  type        = bool
  default     = true
}
