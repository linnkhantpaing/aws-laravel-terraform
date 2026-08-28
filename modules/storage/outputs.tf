output "app_bucket_id" {
  value = aws_s3_bucket.app.id
}

output "app_bucket_arn" {
  value = aws_s3_bucket.app.arn
}

output "app_bucket_domain_name" {
  description = "Regional domain -- use for presigned URL generation"
  value       = aws_s3_bucket.app.bucket_regional_domain_name
}

output "artifacts_bucket_id" {
  value = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  value = aws_s3_bucket.artifacts.arn
}
