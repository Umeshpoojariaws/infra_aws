#!/bin/bash

# AWS Multi-Account Setup Automation Script
# This script automates the creation of AWS accounts and IAM roles for the CI/CD pipeline

set -euo pipefail

# Configuration
ORGANIZATION_ID=""
MAIN_ACCOUNT_ID=""
GITHUB_ORG=""
GITHUB_REPO=""
AWS_REGION="us-east-1"
ENVIRONMENTS=("dev" "staging" "prod")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Get organization ID if not provided
get_organization_id() {
    if [ -z "$ORGANIZATION_ID" ]; then
        log "Retrieving organization ID..."
        ORGANIZATION_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
        success "Organization ID: $ORGANIZATION_ID"
    fi
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

# Create GitHub Actions role in main account
create_github_actions_role() {
    log "Creating GitHub Actions role in main account..."
    
    local role_name="GitHubActionsOIDCRole"
    local trust_policy_file="/tmp/github-actions-trust-policy.json"
    local permissions_policy_file="/tmp/github-actions-permissions-policy.json"
    
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

    # Create permissions policy
    cat > "$permissions_policy_file" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
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
        "s3:AbortMultipartUpload",
        "s3:PutBucketVersioning",
        "s3:GetBucketVersioning",
        "s3:PutBucketEncryption",
        "s3:GetBucketEncryption",
        "s3:PutBucketAcl",
        "s3:GetBucketAcl"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*",
        "arn:aws:s3:::terraform-backups-*",
        "arn:aws:s3:::terraform-backups-*/*"
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
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
    },
    {
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:DELETE",
        "apigateway:PATCH",
        "apigateway:UPDATE"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetHostedZone",
        "route53:CreateHostedZone",
        "route53:DeleteHostedZone",
        "route53:ListResourceRecordSets",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange",
        "route53:ListTagsForResource"
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
      ],
      "Resource": "*"
    },
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
        "sts:GetCallerIdentity",
        "sts:GetSessionToken",
        "sts:AssumeRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/eks/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:PutParameter",
        "ssm:DeleteParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/terraform/*"
    }
  ]
}
EOF

    # Create role
    aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "file://$trust_policy_file"
    
    # Attach permissions policy
    aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "GitHubActionsPermissions" \
        --policy-document "file://$permissions_policy_file"
    
    success "GitHub Actions role created: $role_name"
}

# Create environment-specific roles in each account
create_environment_roles() {
    log "Creating environment-specific roles..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        log "Setting up $env environment..."
        
        # Get account ID for this environment
        local account_id=$(get_account_id "$env")
        
        if [ -z "$account_id" ]; then
            warning "Account for $env environment not found, skipping..."
            continue
        fi
        
        # Create role in environment account
        create_role_in_account "$account_id" "$env"
    done
}

# Get account ID for environment
get_account_id() {
    local env=$1
    local account_name="${env}-shared"
    
    aws organizations list-accounts \
        --query "Accounts[?Name=='$account_name'].Id" \
        --output text
}

# Create role in specific account
create_role_in_account() {
    local account_id=$1
    local env=$2
    local role_name="GitHubActions${env^}Role"
    
    log "Creating role $role_name in account $account_id..."
    
    # Create trust policy for cross-account access
    local trust_policy_file="/tmp/${env}-trust-policy.json"
    cat > "$trust_policy_file" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${MAIN_ACCOUNT_ID}:role/GitHubActionsOIDCRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${env}-environment"
        }
      }
    }
  ]
}
EOF

    # Create role in target account using STS assume role
    aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
        --role-session-name "SetupSession" \
        --external-id "${env}-environment" \
        --query 'Credentials' \
        --output text > /tmp/creds.txt
    
    local access_key=$(awk 'NR==1{print $1}' /tmp/creds.txt)
    local secret_key=$(awk 'NR==2{print $1}' /tmp/creds.txt)
    local session_token=$(awk 'NR==3{print $1}' /tmp/creds.txt)
    
    # Create role using temporary credentials
    AWS_ACCESS_KEY_ID=$access_key \
    AWS_SECRET_ACCESS_KEY=$secret_key \
    AWS_SESSION_TOKEN=$session_token \
    aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "file://$trust_policy_file"
    
    # Attach administrator policy
    AWS_ACCESS_KEY_ID=$access_key \
    AWS_SECRET_ACCESS_KEY=$secret_key \
    AWS_SESSION_TOKEN=$session_token \
    aws iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
    
    success "Role $role_name created in account $account_id"
}

# Create S3 buckets for Terraform state
create_s3_buckets() {
    log "Creating S3 buckets for Terraform state..."
    
    local buckets=(
        "terraform-state-${MAIN_ACCOUNT_ID}"
        "terraform-backups-${MAIN_ACCOUNT_ID}"
    )
    
    for bucket in "${buckets[@]}"; do
        if aws s3 ls "s3://$bucket" &> /dev/null; then
            warning "Bucket $bucket already exists"
        else
            aws s3 mb "s3://$bucket" --region "$AWS_REGION"
            
            # Enable versioning
            aws s3api put-bucket-versioning \
                --bucket "$bucket" \
                --versioning-configuration Status=Enabled
            
            # Enable encryption
            aws s3api put-bucket-encryption \
                --bucket "$bucket" \
                --server-side-encryption-configuration '{
                    "Rules": [{
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }]
                }'
            
            success "Bucket $bucket created with versioning and encryption"
        fi
    done
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

# Create GitHub repository secrets
setup_github_secrets() {
    if ! command -v gh &> /dev/null; then
        warning "GitHub CLI not found, skipping GitHub secrets setup"
        return 0
    fi
    
    log "Setting up GitHub repository secrets..."
    
    local role_arn="arn:aws:iam::${MAIN_ACCOUNT_ID}:role/GitHubActionsOIDCRole"
    
    gh secret set AWS_ROLE_ARN -b"$role_arn"
    
    success "GitHub secrets configured"
}

# Generate configuration files
generate_config_files() {
    log "Generating configuration files..."
    
    # Update terraform-ci.yml with correct account ID
    local ci_file="infra_aws/git/.github/workflows/terraform-ci.yml"
    if [ -f "$ci_file" ]; then
        sed -i.bak "s/ACCOUNT_ID/$MAIN_ACCOUNT_ID/g" "$ci_file"
        sed -i.bak "s/ORGANIZATION/$GITHUB_ORG/g" "$ci_file"
        sed -i.bak "s/REPOSITORY/$GITHUB_REPO/g" "$ci_file"
        rm "${ci_file}.bak"
        success "Updated CI workflow with account and repository information"
    fi
    
    # Create environment configuration
    cat > "infra_aws/git/environments/accounts.tf" << EOF
# Environment Account IDs
locals {
  accounts = {
    dev     = "$(get_account_id "dev")"
    staging = "$(get_account_id "staging")"
    prod    = "$(get_account_id "prod")"
  }
  
  role_arns = {
    dev     = "arn:aws:iam::\${local.accounts.dev}:role/GitHubActionsDevRole"
    staging = "arn:aws:iam::\${local.accounts.staging}:role/GitHubActionsStagingRole"
    prod    = "arn:aws:iam::\${local.accounts.prod}:role/GitHubActionsProdRole"
  }
}
EOF
    
    success "Generated environment configuration"
}

# Main execution
main() {
    log "Starting AWS multi-account setup automation..."
    
    # Check if required variables are set
    if [ -z "$MAIN_ACCOUNT_ID" ] || [ -z "$GITHUB_ORG" ] || [ -z "$GITHUB_REPO" ]; then
        error "Please set MAIN_ACCOUNT_ID, GITHUB_ORG, and GITHUB_REPO environment variables"
        echo "Usage: MAIN_ACCOUNT_ID=123456789012 GITHUB_ORG=myorg GITHUB_REPO=myrepo ./setup-accounts.sh"
        exit 1
    fi
    
    check_prerequisites
    get_organization_id
    create_oidc_provider
    create_github_actions_role
    create_environment_roles
    create_s3_buckets
    create_dynamodb_table
    setup_github_secrets
    generate_config_files
    
    success "AWS multi-account setup completed successfully!"
    log "Next steps:"
    log "1. Review the generated configuration files"
    log "2. Set up GitHub repository secrets if not done automatically"
    log "3. Test the CI/CD pipeline with a sample deployment"
    log "4. Consider implementing additional security controls as needed"
}

# Run main function
main "$@"