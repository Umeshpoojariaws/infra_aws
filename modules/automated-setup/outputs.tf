# Automated Setup Module Outputs

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = var.enable_github_actions_role ? aws_iam_role.github_actions[0].arn : null
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions role"
  value       = var.enable_github_actions_role ? aws_iam_role.github_actions[0].name : null
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.enable_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "terraform_state_bucket" {
  description = "Name of the Terraform state bucket"
  value       = var.enable_s3_buckets ? aws_s3_bucket.terraform_state[0].bucket : null
}

output "terraform_backups_bucket" {
  description = "Name of the Terraform backups bucket"
  value       = var.enable_s3_buckets ? aws_s3_bucket.terraform_backups[0].bucket : null
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = var.enable_dynamodb_table ? aws_dynamodb_table.terraform_locks[0].name : null
}

output "environment_role_arns" {
  description = "ARNs of environment-specific roles"
  value       = var.enable_environment_roles ? { for env in var.environments : env => "arn:aws:iam::${var.main_account_id}:role/GitHubActions${title(env)}Role" } : {}
}

output "github_actions_permissions_policy_arn" {
  description = "ARN of the GitHub Actions permissions policy"
  value       = var.enable_github_actions_role ? aws_iam_policy.github_actions_permissions[0].arn : null
}