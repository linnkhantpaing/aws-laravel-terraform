variable "name_prefix" {
  description = "Prefix for all resource names, e.g. myapp-prod"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Two availability zones. RDS requires a subnet group spanning 2+ AZs even for Single-AZ."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "Exactly two availability zones are required -- one public and one private subnet are created per AZ."
  }
}

variable "region" {
  description = "AWS region (needed for the S3 gateway endpoint service name)"
  type        = string
}