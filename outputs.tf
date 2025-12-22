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

output "auditor_console_password" {
  description = "Initial Password for the External Auditor"
  value       = aws_iam_user_login_profile.auditor_console.password
  sensitive   = true # Click 'Sensitive' in TFC UI to reveal
}

output "auditor_console_url" {
  description = "AWS Console Sign-in Link"
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

# output "bypass_role_arn" {
#   value = aws_iam_role.bypass.arn
# }