# Automated AWS Account and IAM Setup
# This file uses the automated-setup module to create all necessary accounts and roles

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-automated-setup"
    key            = "automated-setup.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# Configuration variables
locals {
  # Replace these with your actual values
  organization_id = "o-1234567890"
  main_account_id = "123456789012"
  github_org      = "your-organization"
  github_repo     = "your-repository"
  
  environments = ["dev", "staging", "prod"]
  
  common_tags = {
    ManagedBy   = "terraform"
    Environment = "global"
    Project     = "aws-multi-account-setup"
  }
}

# Use the automated setup module
module "automated_setup" {
  source = "../modules/automated-setup"

  organization_id     = local.organization_id
  main_account_id     = local.main_account_id
  github_org          = local.github_org
  github_repo         = local.github_repo
  environments        = local.environments
  enable_oidc_provider = true
  enable_github_actions_role = true
  enable_environment_roles = true
  enable_s3_buckets   = true
  enable_dynamodb_table = true
  tags               = local.common_tags
}

# Create AWS Organizations accounts for each environment
resource "aws_organizations_account" "environments" {
  for_each = { for env in local.environments : env => env }

  name      = "${each.key}-shared"
  email     = "${each.key}-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.environments.id

  tags = merge({
    Environment = each.key
    Purpose     = "shared-services"
    AccountType = "shared-services"
  }, local.common_tags)
}

# Create Organizational Units for environments
resource "aws_organizations_organizational_unit" "environments" {
  name      = "environments"
  parent_id = aws_organizations_organization.root.roots[0].id

  tags = merge({
    Name        = "environments"
    Environment = "global"
  }, local.common_tags)
}

resource "aws_organizations_organizational_unit" "dev" {
  name      = "dev"
  parent_id = aws_organizations_organizational_unit.environments.id

  tags = merge({
    Name        = "dev"
    Environment = "dev"
  }, local.common_tags)
}

resource "aws_organizations_organizational_unit" "staging" {
  name      = "staging"
  parent_id = aws_organizations_organizational_unit.environments.id

  tags = merge({
    Name        = "staging"
    Environment = "staging"
  }, local.common_tags)
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "prod"
  parent_id = aws_organizations_organizational_unit.environments.id

  tags = merge({
    Name        = "prod"
    Environment = "prod"
  }, local.common_tags)
}

# Move accounts to their respective OUs
resource "aws_organizations_account" "dev_shared" {
  name      = "dev-shared"
  email     = "dev-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.dev.id

  tags = merge({
    Environment = "dev"
    Purpose     = "shared-services"
    AccountType = "shared-services"
  }, local.common_tags)
}

resource "aws_organizations_account" "staging_shared" {
  name      = "staging-shared"
  email     = "staging-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.staging.id

  tags = merge({
    Environment = "staging"
    Purpose     = "shared-services"
    AccountType = "shared-services"
  }, local.common_tags)
}

resource "aws_organizations_account" "prod_shared" {
  name      = "prod-shared"
  email     = "prod-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.prod.id

  tags = merge({
    Environment = "prod"
    Purpose     = "shared-services"
    AccountType = "shared-services"
  }, local.common_tags)
}

# Outputs for easy reference
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = module.automated_setup.github_actions_role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = module.automated_setup.oidc_provider_arn
}

output "terraform_state_bucket" {
  description = "Name of the Terraform state bucket"
  value       = module.automated_setup.terraform_state_bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = module.automated_setup.dynamodb_table_name
}

output "environment_account_ids" {
  description = "Account IDs for each environment"
  value = {
    dev     = aws_organizations_account.dev_shared.id
    staging = aws_organizations_account.staging_shared.id
    prod    = aws_organizations_account.prod_shared.id
  }
}

output "environment_role_arns" {
  description = "ARNs of environment-specific roles"
  value       = module.automated_setup.environment_role_arns
}

output "github_actions_permissions_policy_arn" {
  description = "ARN of the GitHub Actions permissions policy"
  value       = module.automated_setup.github_actions_permissions_policy_arn
}

# Instructions for next steps
output "setup_complete_instructions" {
  description = "Instructions for completing the setup"
  value = <<-EOT
    Setup Complete! Next steps:
    
    1. Configure GitHub repository secrets:
       - AWS_ROLE_ARN: ${module.automated_setup.github_actions_role_arn}
    
    2. Update CI/CD pipeline configuration with:
       - Account IDs: ${join(", ", values(aws_organizations_account.environments[*].id))}
       - Role ARNs: ${join(", ", values(module.automated_setup.environment_role_arns))}
    
    3. Test the setup:
       - Create a test branch and PR
       - Verify GitHub Actions can assume roles
       - Check S3 bucket and DynamoDB table creation
    
    4. Deploy infrastructure:
       - cd environments/dev/shared
       - terraform init
       - terraform apply
    
    All accounts and IAM roles have been created automatically!
  EOT
}