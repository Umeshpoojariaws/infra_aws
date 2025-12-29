# Automated Setup Module Variables

variable "organization_id" {
  description = "AWS Organization ID"
  type        = string
}

variable "main_account_id" {
  description = "Main account ID for GitHub Actions role"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "environments" {
  description = "List of environments to create accounts for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "enable_oidc_provider" {
  description = "Whether to create OIDC provider"
  type        = bool
  default     = true
}

variable "enable_github_actions_role" {
  description = "Whether to create GitHub Actions role"
  type        = bool
  default     = true
}

variable "enable_environment_roles" {
  description = "Whether to create environment-specific roles"
  type        = bool
  default     = true
}

variable "enable_s3_buckets" {
  description = "Whether to create S3 buckets for Terraform state"
  type        = bool
  default     = true
}

variable "enable_dynamodb_table" {
  description = "Whether to create DynamoDB table for state locking"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}