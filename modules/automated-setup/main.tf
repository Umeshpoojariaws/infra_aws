# Automated AWS Account and IAM Setup Module
# This module automates the creation of AWS accounts and IAM roles for CI/CD

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
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

# Create OIDC provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_oidc_provider ? 1 : 0

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
  }, var.tags)
}

# Create GitHub Actions role in main account
resource "aws_iam_role" "github_actions" {
  count = var.enable_github_actions_role ? 1 : 0

  name = "GitHubActionsOIDCRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github[0].arn
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

  tags = merge({
    Name        = "github-actions-role"
    Environment = "global"
  }, var.tags)
}

# Create GitHub Actions permissions policy
resource "aws_iam_policy" "github_actions_permissions" {
  count = var.enable_github_actions_role ? 1 : 0

  name        = "GitHubActionsPermissions"
  description = "Permissions for GitHub Actions to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
          "s3:AbortMultipartUpload",
          "s3:PutBucketVersioning",
          "s3:GetBucketVersioning",
          "s3:PutBucketEncryption",
          "s3:GetBucketEncryption",
          "s3:PutBucketAcl",
          "s3:GetBucketAcl"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-*",
          "arn:aws:s3:::terraform-state-*/*",
          "arn:aws:s3:::terraform-backups-*",
          "arn:aws:s3:::terraform-backups-*/*"
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
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/terraform-locks"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:ReplaceRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateVpcPeeringConnection",
          "ec2:AcceptVpcPeeringConnection",
          "ec2:DeleteVpcPeeringConnection",
          "ec2:ModifyVpcPeeringConnectionOptions",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:ListNodegroups",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:CreateFargateProfile",
          "eks:DeleteFargateProfile",
          "eks:DescribeFargateProfile",
          "eks:ListFargateProfiles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:StartDBInstance",
          "rds:StopDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:ModifyDBSubnetGroup",
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:DELETE",
          "apigateway:PATCH",
          "apigateway:UPDATE"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListTagsForResource"
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
          "iam:GetRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:CreateServiceLinkedRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy"
        ]
        Resource = "*"
      },
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
          "sts:GetCallerIdentity",
          "sts:GetSessionToken",
          "sts:AssumeRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/eks/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter",
          "ssm:DeleteParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/terraform/*"
      }
    ]
  })

  tags = merge({
    Name        = "github-actions-permissions"
    Environment = "global"
  }, var.tags)
}

# Attach permissions policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_permissions" {
  count = var.enable_github_actions_role ? 1 : 0

  role       = aws_iam_role.github_actions[0].name
  policy_arn = aws_iam_policy.github_actions_permissions[0].arn
}

# Create S3 buckets for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = "terraform-state-${var.main_account_id}"

  tags = merge({
    Name        = "terraform-state"
    Environment = "global"
  }, var.tags)
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "terraform_backups" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = "terraform-backups-${var.main_account_id}"

  tags = merge({
    Name        = "terraform-backups"
    Environment = "global"
  }, var.tags)
}

resource "aws_s3_bucket_versioning" "terraform_backups" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = aws_s3_bucket.terraform_backups[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_backups" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = aws_s3_bucket.terraform_backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_backups" {
  count = var.enable_s3_buckets ? 1 : 0

  bucket = aws_s3_bucket.terraform_backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  count = var.enable_dynamodb_table ? 1 : 0

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
  }, var.tags)
}

# Create environment-specific roles
resource "aws_iam_role" "environment_roles" {
  count = var.enable_environment_roles ? length(var.environments) : 0

  name = "GitHubActions${title(var.environments[count.index])}Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.main_account_id}:role/GitHubActionsOIDCRole"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "${var.environments[count.index]}-environment"
        }
      }
    }]
  })

  tags = merge({
    Name        = "github-actions-${var.environments[count.index]}-role"
    Environment = var.environments[count.index]
  }, var.tags)
}

# Attach administrator policy to environment roles
resource "aws_iam_role_policy_attachment" "environment_admin" {
  count = var.enable_environment_roles ? length(var.environments) : 0

  role       = aws_iam_role.environment_roles[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Outputs
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