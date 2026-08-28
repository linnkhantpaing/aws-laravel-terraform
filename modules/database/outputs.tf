output "endpoint" {
  description = "Hostname only -- goes in DB_HOST"
  value       = aws_db_instance.main.address
}

output "port" {
  value = aws_db_instance.main.port
}

output "database_name" {
  value = aws_db_instance.main.db_name
}

output "username" {
  value = aws_db_instance.main.username
}

output "master_secret_arn" {
  description = "AWS-managed secret holding the master password. EC2 reads this at deploy time."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "kms_key_arn" {
  value = aws_kms_key.rds.arn
}

output "instance_id" {
  value = aws_db_instance.main.id
}

output "instance_identifier" {
  value = aws_db_instance.main.identifier
}

output "instance_arn" {
  description = "EC2 needs this to be allowed rds:DescribeDBInstances at deploy time."
  value       = aws_db_instance.main.arn
}
