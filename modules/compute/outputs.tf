output "instance_id" {
  value = aws_instance.app.id
}

output "private_ip" {
  value = aws_instance.app.private_ip
}

output "public_ip" {
  description = "Point your GoDaddy A record here"
  value       = aws_eip.app.public_ip
}

output "iam_role_arn" {
  value = aws_iam_role.app.arn
}

output "iam_role_name" {
  value = aws_iam_role.app.name
}
