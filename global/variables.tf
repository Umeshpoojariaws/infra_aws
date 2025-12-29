# Global Variables for AWS Organization Setup

variable "main_account_id" {
  description = "Main account ID for the management account"
  type        = string
  default     = "123456789012"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "your-organization"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "your-repository"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy   = "terraform"
    Environment = "global"
    Project     = "aws-multi-account-setup"
  }
}