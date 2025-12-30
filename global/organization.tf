# Simple AWS Organizations Setup for Beginners
# This version works within AWS account limits and handles existing accounts gracefully
# Uses a simple, reliable approach without problematic data sources

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Management account region
}

# Create AWS Organization
resource "aws_organizations_organization" "root" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]
}

# Create Organizational Units
resource "aws_organizations_organizational_unit" "environments" {
  name      = "environments"
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "dev" {
  name      = "dev"
  parent_id = aws_organizations_organizational_unit.environments.id
}

resource "aws_organizations_organizational_unit" "staging" {
  name      = "staging"
  parent_id = aws_organizations_organizational_unit.environments.id
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "prod"
  parent_id = aws_organizations_organizational_unit.environments.id
}

# Create Accounts for Dev Environment (within AWS free tier limits)
resource "aws_organizations_account" "dev_shared" {
  name      = "dev-shared"
  email     = "umesh.poojariaws+viyansh@gmail.com"
  parent_id = aws_organizations_organizational_unit.dev.id

  lifecycle {
    ignore_changes = [name, email, parent_id]
  }
}

# Create Accounts for Staging Environment (within AWS free tier limits)
resource "aws_organizations_account" "staging_shared" {
  name      = "staging-shared"
  email     = "umesh.poojariaws+viyansh@gmail.com"
  parent_id = aws_organizations_organizational_unit.staging.id

  lifecycle {
    ignore_changes = [name, email, parent_id]
  }
}

# Create Accounts for Prod Environment (within AWS free tier limits)
resource "aws_organizations_account" "prod_shared" {
  name      = "prod-shared"
  email     = "umesh.poojariaws+viyansh@gmail.com"
  parent_id = aws_organizations_organizational_unit.prod.id

  lifecycle {
    ignore_changes = [name, email, parent_id]
  }
}

# Service Control Policy to restrict certain actions
resource "aws_organizations_policy" "scp_restrictions" {
  name        = "scp-restrictions"
  description = "Service Control Policy to restrict certain actions"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyS3PublicAccess"
        Effect    = "Deny"
        Action    = [
          "s3:PutAccountPublicAccessBlock",
          "s3:PutPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "s3:PublicAccessBlockIgnorePublicAcls" = "true",
            "s3:PublicAccessBlockRestrictPublicBuckets" = "true"
          }
        }
      },
      {
        Sid    = "DenyRootAccountActions"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })
}

# Attach SCP to the environments OU
resource "aws_organizations_policy_attachment" "scp_to_environments" {
  policy_id = aws_organizations_policy.scp_restrictions.id
  target_id = aws_organizations_organizational_unit.environments.id
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
}

# Create GitHub Actions role in main account
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsOIDCRole"

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
            "repo:${var.github_org}/${var.github_repo}:*",
            "repo:${var.github_org}/*:ref:refs/heads/main"
          ]
        }
      }
    }]
  })
}

# Create GitHub Actions permissions policy
resource "aws_iam_policy" "github_actions_permissions" {
  name        = "GitHubActionsPermissions"
  description = "Permissions for GitHub Actions to manage AWS resources"

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
}

# Attach permissions policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_permissions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_permissions.arn
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${var.main_account_id}"
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

# Create DynamoDB table for state locking (with ignore_existing)
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

  # Ignore if table already exists
  lifecycle {
    ignore_changes = [read_capacity, write_capacity]
  }
}

# Output Organization ID
output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = aws_organizations_organization.root.id
}

# Output Account IDs
output "dev_shared_account_id" {
  description = "The ID of the dev-shared account"
  value       = aws_organizations_account.dev_shared.id
}

output "staging_shared_account_id" {
  description = "The ID of the staging-shared account"
  value       = aws_organizations_account.staging_shared.id
}

output "prod_shared_account_id" {
  description = "The ID of the prod-shared account"
  value       = aws_organizations_account.prod_shared.id
}

# Output GitHub Actions Information
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
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

# Instructions for next steps
output "setup_complete_instructions" {
  description = "Instructions for completing the setup"
  value = <<-EOT
    Organization Setup Complete! Next steps:
    
    1. Configure GitHub repository secrets:
       - AWS_ROLE_ARN: ${aws_iam_role.github_actions.arn}
    
    2. Update CI/CD pipeline configuration with:
       - Account IDs: ${join(", ", [aws_organizations_account.dev_shared.id, aws_organizations_account.staging_shared.id, aws_organizations_account.prod_shared.id])}
       - Role ARNs: GitHub Actions role ARN above
    
    3. Deploy infrastructure to each environment:
       - cd environments/dev/shared
       - terraform init
       - terraform apply
    
    All accounts and basic IAM roles have been created!
    
    Note: This setup creates 3 accounts (dev-shared, staging-shared, prod-shared)
    which works within AWS's default account limits.
  EOT
}