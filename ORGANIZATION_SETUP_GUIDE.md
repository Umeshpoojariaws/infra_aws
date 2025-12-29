# AWS Organization Setup Guide

This guide provides instructions for setting up a minimal AWS Organization with the necessary roles for Terraform to create and manage accounts.

## Overview

This setup creates:
- **AWS Organization** with Organizational Units (OUs) for each environment
- **Accounts** for dev, staging, and prod environments
- **Minimal IAM roles** for Terraform to manage resources
- **S3 bucket** for Terraform state storage
- **DynamoDB table** for state locking

## Quick Start

### Option 1: Using the Shell Script (Recommended)

```bash
# Make the script executable
chmod +x scripts/setup-organization.sh

# Run the setup
MAIN_ACCOUNT_ID=123456789012 GITHUB_ORG=myorg GITHUB_REPO=myrepo ./scripts/setup-organization.sh
```

### Option 2: Using Terraform

```bash
# Navigate to the global setup directory
cd global

# Initialize and apply
terraform init
terraform apply -var="main_account_id=123456789012" \
                -var="github_org=myorg" \
                -var="github_repo=myrepo"
```

## What Gets Created

### 1. AWS Organization Structure
```
AWS Organization Root
├── environments OU
    ├── dev OU
    │   └── dev-shared account
    ├── staging OU
    │   └── staging-shared account
    └── prod OU
        └── prod-shared account
```

### 2. IAM Roles and Policies
- **TerraformRole**: Minimal role for GitHub Actions
- **TerraformPermissions**: Policy with minimal required permissions
- **OIDC Provider**: For GitHub Actions authentication

### 3. Infrastructure for Terraform
- **S3 Bucket**: `terraform-state-ACCOUNT_ID` with encryption and versioning
- **DynamoDB Table**: `terraform-locks` for state locking

## Minimal Permissions

The Terraform role has only the permissions needed to:

### AWS Organizations
- `organizations:DescribeOrganization` - Get organization info
- `organizations:ListAccounts` - List accounts
- `organizations:DescribeAccount` - Get account details
- `organizations:ListOrganizationalUnitsForParent` - List OUs
- `organizations:DescribeOrganizationalUnit` - Get OU details
- `organizations:ListChildren` - List child accounts/OU
- `organizations:ListParents` - Get parent OUs
- `organizations:ListRoots` - Get root OUs

### IAM Management
- `iam:CreateRole` - Create new roles
- `iam:DeleteRole` - Delete roles
- `iam:AttachRolePolicy` - Attach policies to roles
- `iam:DetachRolePolicy` - Detach policies from roles
- `iam:CreatePolicy` - Create new policies
- `iam:DeletePolicy` - Delete policies
- `iam:PutRolePolicy` - Add inline policies to roles
- `iam:DeleteRolePolicy` - Remove inline policies from roles
- `iam:PassRole` - Pass roles to other services
- `iam:ListRoles` - List roles
- `iam:GetRole` - Get role details

### S3 State Storage
- `s3:CreateBucket` - Create state buckets
- `s3:GetBucket*` - Get bucket information
- `s3:ListBucket` - List bucket contents
- `s3:PutBucket*` - Configure bucket settings
- `s3:DeleteBucket` - Delete buckets
- `s3:PutObject` - Upload state files
- `s3:GetObject` - Download state files
- `s3:DeleteObject` - Delete state files
- `s3:ListBucketMultipartUploads` - List multipart uploads
- `s3:ListMultipartUploadParts` - List upload parts
- `s3:AbortMultipartUpload` - Cancel uploads

### DynamoDB State Locking
- `dynamodb:CreateTable` - Create lock table
- `dynamodb:DescribeTable` - Get table info
- `dynamodb:GetItem` - Get lock items
- `dynamodb:PutItem` - Create lock items
- `dynamodb:UpdateItem` - Update lock items
- `dynamodb:DeleteItem` - Delete lock items
- `dynamodb:Query` - Query lock items
- `dynamodb:Scan` - Scan lock items

### STS (Security Token Service)
- `sts:GetCallerIdentity` - Get identity info
- `sts:GetSessionToken` - Get session tokens

## Next Steps After Setup

### 1. Configure GitHub Actions
Set up the GitHub repository secret:
- `AWS_ROLE_ARN`: `arn:aws:iam::ACCOUNT_ID:role/TerraformRole`

### 2. Update CI/CD Pipeline
Modify your GitHub Actions workflow to use the Terraform role:

```yaml
- name: Setup AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT_ID:role/TerraformRole
    aws-region: us-east-1
```

### 3. Deploy Infrastructure
Now you can deploy infrastructure to each environment:

```bash
# Deploy to dev environment
cd environments/dev/shared
terraform init
terraform apply

# Deploy to staging environment
cd ../../staging/shared
terraform init
terraform apply

# Deploy to prod environment
cd ../../prod/shared
terraform init
terraform apply
```

### 4. Create Additional Roles
When deploying to each environment, Terraform can create environment-specific roles with the permissions needed for that environment's resources.

## Security Benefits

### Minimal Attack Surface
- Only necessary permissions are granted
- No broad administrator access
- Clear separation of concerns

### Audit Trail
- All actions are logged via CloudTrail
- Role assumption is tracked
- Changes are version controlled

### Isolation
- Each environment has its own account
- Roles are scoped to specific environments
- Cross-account access is controlled

## Troubleshooting

### Common Issues

#### 1. "AccessDenied" Errors
Check that the Terraform role has the required permissions:
```bash
aws iam get-role --role-name TerraformRole
aws iam list-attached-role-policies --role-name TerraformRole
```

#### 2. "BucketAlreadyExists" Errors
The S3 bucket name must be globally unique. If you get this error, modify the bucket name in the configuration.

#### 3. "TableAlreadyExists" Errors
The DynamoDB table name must be unique. If you get this error, modify the table name in the configuration.

#### 4. GitHub Actions Authentication Failures
Check the OIDC provider and trust policy:
```bash
aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### Debug Commands

```bash
# Check organization structure
aws organizations list-accounts

# Check IAM roles
aws iam list-roles --query 'Roles[?RoleName==`TerraformRole`].RoleName'

# Check S3 buckets
aws s3 ls | grep terraform

# Check DynamoDB tables
aws dynamodb list-tables
```

## Maintenance

### Adding New Environments
To add a new environment (e.g., "qa"):

1. Add the environment to the `environments` list in the Terraform configuration
2. Re-run the Terraform apply
3. Create the corresponding environment directory structure

### Updating Permissions
To update the Terraform role permissions:

1. Modify the `TerraformPermissions` policy
2. Re-apply the Terraform configuration
3. Test the changes in a non-production environment

### Monitoring
Set up monitoring for:
- S3 bucket usage and costs
- DynamoDB read/write capacity
- IAM role usage and access patterns
- Organization account creation/deletion

This minimal setup provides the foundation for a secure, scalable multi-account AWS environment managed entirely through Terraform.