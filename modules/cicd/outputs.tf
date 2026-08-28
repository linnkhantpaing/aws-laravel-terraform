output "app_name" {
  description = "Pass to `aws deploy create-deployment --application-name`"
  value       = aws_codedeploy_app.main.name
}

output "deployment_group_name" {
  value = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "service_role_arn" {
  value = aws_iam_role.codedeploy.arn
}
