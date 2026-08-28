output "secret_arns" {
  description = "Map of logical name to ARN"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "secret_names" {
  value = { for k, v in aws_secretsmanager_secret.this : k => v.name }
}

output "secret_arn_list" {
  description = "Flat list for IAM policy Resource blocks"
  value       = [for v in aws_secretsmanager_secret.this : v.arn]
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.this["db_credentials"].arn
}

output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.secretsmanager.id
}
