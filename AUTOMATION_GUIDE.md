# AWS Multi-Account Automation Guide

This guide provides comprehensive instructions for automating the creation of AWS accounts and IAM roles for the CI/CD pipeline.

## Overview

The automation setup includes:
- **AWS Organizations**: Multi-account structure with OUs
- **IAM Roles**: GitHub Actions roles with cross-account access
- **OIDC Provider**: Secure authentication without long-lived credentials
- **S3 Buckets**: Terraform state storage with encryption and versioning
- **DynamoDB**: State locking for concurrent operations

## Quick Start

### Option 1: Using the Shell Script (Recommended for Initial Setup)

```bash
# Make the script executable
chmod +x scripts/setup-accounts.sh

# Run the automation script
MAIN_ACCOUNT_ID=123456789012 GITHUB_ORG=myorg GITHUB_REPO=myrepo ./scripts/setup-accounts.sh
```

### Option 2: Using Terraform Module

```bash
# Navigate to the global setup directory
cd global

# Initialize and apply
terraform init
terraform apply -var="organization_id=o-1234567890" \
                -var="main_account_id=123456789012" \
                -var="github_org=myorg" \
                -var="github_repo=myrepo"
```

## Prerequisites

### Required Tools
- AWS CLI v2
- Terraform >= 1.0
- jq (for JSON processing)
- GitHub CLI (optional, for secret setup)

### Required Permissions
The user running the automation needs:
- `organizations:*` permissions
- `iam:*` permissions
- `s3:*` permissions
- `dynamodb:*` permissions
- Ability to create and manage AWS Organizations

### Environment Variables
Set these environment variables before running automation:

```bash
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1
export MAIN_ACCOUNT_ID=123456789012
export GITHUB_ORG=your-organization
export GITHUB_REPO=your-repository
```

## Automation Components

### 1. Shell Script Automation (`scripts/setup-accounts.sh`)

**Features:**
- ✅ OIDC provider creation
- ✅ GitHub Actions role creation
- ✅ Environment-specific roles
- ✅ S3 bucket creation with encryption
- ✅ DynamoDB table creation
- ✅ GitHub repository secret setup
- ✅ Cross-account role assumption

**Usage:**
```bash
# Full automation
./scripts/setup-accounts.sh

# Selective automation
ENABLE_OIDC=false ENABLE_S3=false ./scripts/setup-accounts.sh
```

### 2. Terraform Module (`modules/automated-setup/`)

**Features:**
- ✅ Declarative infrastructure as code
- ✅ Version control and change tracking
- ✅ Reusable across multiple setups
- ✅ Integration with existing Terraform workflows

**Usage:**
```hcl
module "automated_setup" {
  source = "path/to/modules/automated-setup"

  organization_id     = "o-1234567890"
  main_account_id     = "123456789012"
  github_org          = "myorg"
  github_repo         = "myrepo"
  environments        = ["dev", "staging", "prod"]
  enable_oidc_provider = true
  # ... other variables
}
```

### 3. Complete Setup (`global/automated-setup.tf`)

**Features:**
- ✅ Full AWS Organization setup
- ✅ Account creation and organization
- ✅ Complete IAM role setup
- ✅ Resource tagging and organization

## Step-by-Step Process

### Step 1: Organization Setup
The automation will:
1. Create Organizational Units (OUs) for each environment
2. Create AWS accounts for each environment
3. Move accounts to appropriate OUs
4. Apply SCPs (Service Control Policies) for security

### Step 2: IAM Setup
The automation will:
1. Create OIDC provider for GitHub authentication
2. Create main GitHub Actions role in the management account
3. Create environment-specific roles in each account
4. Set up cross-account trust relationships
5. Attach appropriate permissions policies

### Step 3: Infrastructure Setup
The automation will:
1. Create S3 buckets for Terraform state storage
2. Enable versioning and encryption on S3 buckets
3. Create DynamoDB table for state locking
4. Configure bucket policies and access controls

### Step 4: GitHub Integration
The automation will:
1. Set up GitHub repository secrets
2. Configure OIDC trust relationships
3. Validate GitHub Actions permissions

## Configuration Options

### Environment Variables
```bash
# Required
MAIN_ACCOUNT_ID=123456789012
GITHUB_ORG=myorg
GITHUB_REPO=myrepo

# Optional
AWS_REGION=us-east-1
ORGANIZATION_ID=o-1234567890
ENVIRONMENTS="dev,staging,prod"

# Selective automation
ENABLE_OIDC=true
ENABLE_GITHUB_ACTIONS_ROLE=true
ENABLE_ENVIRONMENT_ROLES=true
ENABLE_S3_BUCKETS=true
ENABLE_DYNAMODB_TABLE=true
```

### Terraform Variables
```hcl
variable "organization_id" {
  description = "AWS Organization ID"
  type        = string
  default     = "o-1234567890"
}

variable "main_account_id" {
  description = "Main account ID for GitHub Actions role"
  type        = string
  default     = "123456789012"
}

variable "environments" {
  description = "List of environments to create accounts for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}
```

## Security Features

### 1. OIDC Authentication
- No long-lived AWS credentials
- GitHub Actions authenticates using OIDC tokens
- Automatic token refresh and rotation

### 2. Cross-Account Access
- Environment-specific roles with external ID validation
- Principle of least privilege
- Audit trail for all role assumptions

### 3. Resource Protection
- S3 bucket encryption and versioning
- DynamoDB table with provisioned throughput
- IAM policies with minimal required permissions

### 4. Organization Controls
- SCPs to restrict dangerous operations
- Account isolation and separation
- Centralized governance and monitoring

## Troubleshooting

### Common Issues

#### 1. "AccessDenied" Errors
```bash
# Check if you have required permissions
aws iam get-user --user-name $(aws sts get-caller-identity --query UserId --output text)
```

#### 2. "Account already exists" Errors
```bash
# Check existing accounts
aws organizations list-accounts
```

#### 3. "OIDC provider already exists" Warnings
```bash
# Check existing OIDC providers
aws iam list-open-id-connect-providers
```

#### 4. GitHub Actions Authentication Failures
```bash
# Test OIDC provider
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsOIDCRole \
  --role-session-name test \
  --web-identity-token $TOKEN
```

### Debug Commands

```bash
# Check organization structure
aws organizations list-accounts-for-parent --parent-id $(aws organizations list-roots --query 'Roots[0].Id' --output text)

# Check IAM roles
aws iam list-roles --query 'Roles[?RoleName!=`null` && contains(RoleName, `GitHubActions`)].RoleName'

# Check S3 buckets
aws s3 ls | grep terraform

# Check DynamoDB tables
aws dynamodb list-tables
```

## Post-Setup Verification

### 1. Verify Account Creation
```bash
aws organizations list-accounts --query 'Accounts[?Name!=`null` && contains(Name, `shared`)].{Name:Name,Id:Id}'
```

### 2. Verify IAM Roles
```bash
aws iam list-roles --query 'Roles[?RoleName!=`null` && contains(RoleName, `GitHubActions`)].RoleName'
```

### 3. Verify S3 Buckets
```bash
aws s3 ls | grep terraform
```

### 4. Verify DynamoDB Table
```bash
aws dynamodb describe-table --table-name terraform-locks
```

### 5. Test GitHub Actions Integration
Create a test workflow to verify authentication:
```yaml
name: Test Setup
on: workflow_dispatch
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - name: Test AWS Authentication
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::ACCOUNT_ID:role/GitHubActionsOIDCRole
        aws-region: us-east-1
    - name: Test AWS CLI
      run: aws sts get-caller-identity
```

## Maintenance and Updates

### 1. Adding New Environments
```bash
# Update environments list
export ENVIRONMENTS="dev,staging,prod,qa"

# Re-run automation
./scripts/setup-accounts.sh
```

### 2. Updating Permissions
```bash
# Modify the permissions policy in the Terraform module
# Re-apply the configuration
terraform apply
```

### 3. Rotating Secrets
OIDC authentication doesn't use secrets, but if you need to update:
- GitHub repository secrets
- S3 bucket encryption keys
- IAM role policies

### 4. Monitoring and Auditing
```bash
# Check CloudTrail logs for role usage
aws logs filter-log-events --log-group-name /aws/cloudtrail/logs --filter-pattern '{ $.eventName = "AssumeRole" }'

# Check IAM access analyzer findings
aws accessanalyzer list-findings --analyzer-name GitHubActionsAnalyzer
```

## Best Practices

### 1. Security
- Use least privilege permissions
- Enable MFA for sensitive operations
- Regularly review and audit access
- Use SCPs to restrict dangerous operations

### 2. Organization
- Use consistent naming conventions
- Tag all resources appropriately
- Organize accounts in logical OUs
- Document all changes and configurations

### 3. Monitoring
- Enable CloudTrail for all accounts
- Set up CloudWatch alarms for unusual activity
- Monitor cost and usage across accounts
- Use AWS Config for compliance tracking

### 4. Backup and Recovery
- Regularly backup Terraform state
- Test disaster recovery procedures
- Document recovery steps
- Keep multiple copies of critical configurations

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS documentation
3. Check GitHub Actions logs
4. Contact the infrastructure team

This automation setup provides a complete, secure, and scalable foundation for managing AWS multi-account environments with GitHub Actions CI/CD.