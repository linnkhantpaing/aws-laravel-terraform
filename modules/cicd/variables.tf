variable "name_prefix" {
  type = string
}

variable "app_instance_tag_name" {
  description = "Value of the Name tag CodeDeploy matches on"
  type        = string
}

variable "sns_topic_arn" {
  description = "Topic for deployment failure alerts. Empty string disables notifications."
  type        = string
  default     = ""
}
