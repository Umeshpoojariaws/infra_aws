#!/bin/bash

# Simple AWS Organization Setup Script
# Creates only the organization structure and minimal Terraform roles

set -euo pipefail

# Configuration
MAIN_ACCOUNT_ID=""
GITHUB_ORG=""
GITHUB_REPO=""
AWS_REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured properly"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Create S3 bucket for Terraform state
create_s3_bucket() {
    log "Creating S3 bucket for Terraform state..."
    
    local bucket_name="terraform-state-${MAIN_ACCOUNT_ID}"
    
    if aws s3 ls "s3://$bucket_name" &> /dev/null; then
        warning "Bucket $bucket_name already exists"
        return 0
    fi
    
    aws s3 mb "s3://$bucket_name" --region "$AWS_REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$bucket_name" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$bucket_name" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$bucket_name" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    success "S3 bucket $bucket_name created with versioning and encryption"
}

# Create DynamoDB table for state locking
create_dynamodb_table() {
    log "Creating DynamoDB table for state locking..."
    
    local table_name="terraform-locks"
    
    if aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
        warning "DynamoDB table $table_name already exists"
        return 0
    fi
    
    aws dynamodb create-table \
        --table-name "$table_name" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION"
    
    success "DynamoDB table $table_name created"
}

# Create OIDC provider for GitHub
create_oidc_provider() {
    log "Creating OIDC provider for GitHub..."
    
    local provider_arn="arn:aws:iam::${MAIN_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    
    # Check if OIDC provider already exists
    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" &> /dev/null; then
        warning "OIDC provider already exists"
        return 0
    fi
    
    # Create OIDC provider
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    
    success "OIDC provider created"
}

# Create minimal Terraform role
create_terraform_role() {
    log "Creating minimal Terraform role..."
    
    local role_name="TerraformRole"
    local trust_policy_file="/tmp/terraform-trust-policy.json"
    local permissions_policy_file="/tmp/terraform-permissions-policy.json"
    
    # Create trust policy
    cat > "$trust_policy_file" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${MAIN_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:${GITHUB_ORG}/${GITHUB_REPO}:*",
            "repo:${GITHUB_ORG}/*:ref:refs/heads/main"
          ]
        }
      }
    }
  ]
}
EOF

    # Create minimal permissions policy
    cat > "$permissions_policy_file" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "organizations:DescribeOrganization",
        "organizations:ListAccounts",
        "organizations:DescribeAccount",
        "organizations:ListOrganizationalUnitsForParent",
        "organizations:DescribeOrganizationalUnit",
        "organizations:ListChildren",
        "organizations:ListParents",
        "organizations:ListRoots"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "sts:GetSessionToken"
      ],
      "Resource": "*"
    }
  ]
}
EOF

    # Create role
    aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "file://$trust_policy_file"
    
    # Create policy
    aws iam create-policy \
        --policy-name "TerraformPermissions" \
        --policy-document "file://$permissions_policy_file"
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn "arn:aws:iam::${MAIN_ACCOUNT_ID}:policy/TerraformPermissions"
    
    success "Terraform role created: $role_name"
}

# Create GitHub repository secrets
setup_github_secrets() {
    if ! command -v gh &> /dev/null; then
        warning "GitHub CLI not found, skipping GitHub secrets setup"
        return 0
    fi
    
    log "Setting up GitHub repository secrets..."
    
    local role_arn="arn:aws:iam::${MAIN_ACCOUNT_ID}:role/TerraformRole"
    
    gh secret set AWS_ROLE_ARN -b"$role_arn"
    
    success "GitHub secrets configured"
}

# Generate configuration files
generate_config_files() {
    log "Generating configuration files..."
    
    # Create backend configuration
    cat > "backend.tf" << EOF
# Terraform Backend Configuration
terraform {
  backend "s3" {
    bucket         = "terraform-state-${MAIN_ACCOUNT_ID}"
    key            = "terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
EOF
    
    # Create provider configuration
    cat > "providers.tf" << EOF
# AWS Provider Configuration
provider "aws" {
  region = "${AWS_REGION}"
}
EOF
    
    # Create variables file
    cat > "variables.tf" << EOF
# Configuration Variables
variable "main_account_id" {
  description = "Main account ID"
  default     = "${MAIN_ACCOUNT_ID}"
}

variable "github_org" {
  description = "GitHub organization"
  default     = "${GITHUB_ORG}"
}

variable "github_repo" {
  description = "GitHub repository"
  default     = "${GITHUB_REPO}"
}
EOF
    
    success "Configuration files generated"
}

# Main execution
main() {
    log "Starting AWS Organization setup with minimal Terraform roles..."
    
    # Check if required variables are set
    if [ -z "$MAIN_ACCOUNT_ID" ] || [ -z "$GITHUB_ORG" ] || [ -z "$GITHUB_REPO" ]; then
        error "Please set MAIN_ACCOUNT_ID, GITHUB_ORG, and GITHUB_REPO environment variables"
        echo "Usage: MAIN_ACCOUNT_ID=123456789012 GITHUB_ORG=myorg GITHUB_REPO=myrepo ./setup-organization.sh"
        exit 1
    fi
    
    check_prerequisites
    create_s3_bucket
    create_dynamodb_table
    create_oidc_provider
    create_terraform_role
    setup_github_secrets
    generate_config_files
    
    success "AWS Organization setup completed successfully!"
    log "Next steps:"
    log "1. Review the generated configuration files"
    log "2. Set up GitHub repository secrets if not done automatically"
    log "3. Use the organization-setup.tf file to create accounts and OUs"
    log "4. Deploy infrastructure to each environment using the Terraform role"
    log ""
    log "The Terraform role has minimal permissions to:"
    log "- Create and manage IAM roles and policies"
    log "- Manage S3 buckets for state storage"
    log "- Manage DynamoDB for state locking"
    log "- Access AWS Organizations for account information"
}

# Run main function
main "$@"