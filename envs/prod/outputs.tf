output "app_public_ip" {
  description = "Point your DNS provider's A record here"
  value       = module.compute.public_ip
}

output "instance_id" {
  value = module.compute.instance_id
}

output "db_endpoint" {
  value = module.database.endpoint
}

output "db_master_secret_arn" {
  description = "Fetch the DB password from here at deploy time"
  value       = module.database.master_secret_arn
}

output "app_bucket" {
  value = module.storage.app_bucket_id
}

output "artifacts_bucket" {
  value = module.storage.artifacts_bucket_id
}

output "codedeploy_app" {
  value = module.cicd.app_name
}

output "codedeploy_group" {
  value = module.cicd.deployment_group_name
}

output "secret_names" {
  value = module.secrets.secret_names
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "vpc_id" {
  value = module.network.vpc_id
}
