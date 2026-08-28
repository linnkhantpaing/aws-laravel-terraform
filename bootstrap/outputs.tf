output "state_bucket" {
  description = "S3 bucket for Terraform state -- goes in envs/prod/backend.tf"
  value       = aws_s3_bucket.tfstate.id
}

output "tf_plan_role_arn" {
  description = "Role ARN for the plan workflow"
  value       = aws_iam_role.tf_plan.arn
}

output "tf_apply_role_arn" {
  description = "Role ARN for the apply workflow"
  value       = aws_iam_role.tf_apply.arn
}

output "app_deploy_role_arn" {
  description = "Role ARN for the app repo's deploy workflow"
  value       = aws_iam_role.app_deploy.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
