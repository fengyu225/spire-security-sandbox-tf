output "spire_server_role_arn" {
  value = aws_iam_role.spire_server.arn
}

output "db_access_role_arn" {
  value = aws_iam_role.db_access.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.spire.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.oidc.bucket
}

output "oidc_issuer_url" {
  value = local.oidc_url
}

output "rules_bucket_name" {
  value = aws_s3_bucket.rules.bucket
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.plugin.repository_url
}