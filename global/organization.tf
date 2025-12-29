# AWS Organizations Setup
# This file should be run once to establish the multi-account structure

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

# Create Accounts for Dev Environment
resource "aws_organizations_account" "dev_app" {
  name      = "dev-app"
  email     = "dev-app@yourorg.com"
  parent_id = aws_organizations_organizational_unit.dev.id

  tags = {
    Environment = "dev"
    Purpose     = "app"
    AccountType = "application"
  }
}

resource "aws_organizations_account" "dev_ml" {
  name      = "dev-ml"
  email     = "dev-ml@yourorg.com"
  parent_id = aws_organizations_organizational_unit.dev.id

  tags = {
    Environment = "dev"
    Purpose     = "ml"
    AccountType = "machine-learning"
  }
}

resource "aws_organizations_account" "dev_shared" {
  name      = "dev-shared"
  email     = "dev-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.dev.id

  tags = {
    Environment = "dev"
    Purpose     = "shared"
    AccountType = "shared-services"
  }
}

# Create Accounts for Staging Environment
resource "aws_organizations_account" "staging_app" {
  name      = "staging-app"
  email     = "staging-app@yourorg.com"
  parent_id = aws_organizations_organizational_unit.staging.id

  tags = {
    Environment = "staging"
    Purpose     = "app"
    AccountType = "application"
  }
}

resource "aws_organizations_account" "staging_ml" {
  name      = "staging-ml"
  email     = "staging-ml@yourorg.com"
  parent_id = aws_organizations_organizational_unit.staging.id

  tags = {
    Environment = "staging"
    Purpose     = "ml"
    AccountType = "machine-learning"
  }
}

resource "aws_organizations_account" "staging_shared" {
  name      = "staging-shared"
  email     = "staging-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.staging.id

  tags = {
    Environment = "staging"
    Purpose     = "shared"
    AccountType = "shared-services"
  }
}

# Create Accounts for Prod Environment
resource "aws_organizations_account" "prod_app" {
  name      = "prod-app"
  email     = "prod-app@yourorg.com"
  parent_id = aws_organizations_organizational_unit.prod.id

  tags = {
    Environment = "prod"
    Purpose     = "app"
    AccountType = "application"
  }
}

resource "aws_organizations_account" "prod_ml" {
  name      = "prod-ml"
  email     = "prod-ml@yourorg.com"
  parent_id = aws_organizations_organizational_unit.prod.id

  tags = {
    Environment = "prod"
    Purpose     = "ml"
    AccountType = "machine-learning"
  }
}

resource "aws_organizations_account" "prod_shared" {
  name      = "prod-shared"
  email     = "prod-shared@yourorg.com"
  parent_id = aws_organizations_organizational_unit.prod.id

  tags = {
    Environment = "prod"
    Purpose     = "shared"
    AccountType = "shared-services"
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

# Output Organization ID
output "organization_id" {
  value = aws_organizations_organization.root.id
}

# Output Account IDs
output "dev_app_account_id" {
  value = aws_organizations_account.dev_app.id
}

output "dev_ml_account_id" {
  value = aws_organizations_account.dev_ml.id
}

output "dev_shared_account_id" {
  value = aws_organizations_account.dev_shared.id
}