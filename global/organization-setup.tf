# AWS Organization Setup with Minimal Terraform Roles
# This creates only the organization structure and basic roles needed for Terraform

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-organization"
    key            = "organization.tfstate"
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
  main_account_id = "123456789012"  # Your management account ID
  github_org      = "your-organization"
  github_repo     = "your-repository"
  
  environments = ["dev", "staging", "prod"]
  
  common_tags = {
    ManagedBy   = "terraform"
    Environment = "global"
    Project     = "aws-organization-setup"
  }
}

# Create AWS Organization
resource "aws_organizations_organization" "root" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  tags = local.common_tags
}

# Create Organizational Units
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

# Create Accounts for each environment
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

# Create OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge({
    Name        = "github-actions-oidc"
    Environment = "global"
  }, local.common_tags)
}

# Create minimal Terraform role for GitHub Actions
resource "aws_iam_role" "terraform" {
  name = "TerraformRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${local.github_org}/${local.github_repo}:*",
            "repo:${local.github_org}/*:ref:refs/heads/main"
          ]
        }
      }
    }]
  })

  tags = merge({
    Name        = "terraform-role"
    Environment = "global"
  }, local.common_tags)
}

# Create minimal Terraform permissions policy
resource "aws_iam_policy" "terraform_permissions" {
  name        = "TerraformPermissions"
  description = "Minimal permissions for Terraform to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:DescribeAccount",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:DescribeOrganizationalUnit",
          "organizations:ListChildren",
          "organizations:ListParents",
          "organizations:ListRoots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:PassRole",
          "iam:ListRoles",
          "iam:GetRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:GetBucket*",
          "s3:ListBucket",
          "s3:PutBucket*",
          "s3:DeleteBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-*",
          "arn:aws:s3:::terraform-state-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/terraform-locks"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:GetSessionToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge({
    Name        = "terraform-permissions"
    Environment = "global"
  }, local.common_tags)
}

# Attach permissions policy to Terraform role
resource "aws_iam_role_policy_attachment" "terraform_permissions" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform_permissions.arn
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${local.main_account_id}"

  tags = merge({
    Name        = "terraform-state"
    Environment = "global"
  }, local.common_tags)
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge({
    Name        = "terraform-locks"
    Environment = "global"
  }, local.common_tags)
}

# Outputs for easy reference
output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.root.id
}

output "terraform_role_arn" {
  description = "ARN of the Terraform role"
  value       = aws_iam_role.terraform.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_state_bucket" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "environment_account_ids" {
  description = "Account IDs for each environment"
  value = {
    dev     = aws_organizations_account.dev_shared.id
    staging = aws_organizations_account.staging_shared.id
    prod    = aws_organizations_account.prod_shared.id
  }
}

output "terraform_permissions_policy_arn" {
  description = "ARN of the Terraform permissions policy"
  value       = aws_iam_policy.terraform_permissions.arn
}

# Instructions for next steps
output "setup_complete_instructions" {
  description = "Instructions for completing the setup"
  value = <<-EOT
    Organization Setup Complete! Next steps:
    
    1. Configure GitHub repository secrets:
       - AWS_ROLE_ARN: ${aws_iam_role.terraform.arn}
    
    2. Update your CI/CD pipeline to use the Terraform role
    
    3. Deploy infrastructure to each environment:
       - cd environments/dev/shared
       - terraform init
       - terraform apply
    
    4. The Terraform role has minimal permissions to:
       - Create and manage IAM roles and policies
       - Manage S3 buckets for state storage
       - Manage DynamoDB for state locking
       - Access AWS Organizations for account information
    
    All accounts and basic IAM roles have been created!
  EOT
}