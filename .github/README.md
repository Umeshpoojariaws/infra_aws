# GitHub Actions CI/CD Pipeline

This directory contains the GitHub Actions workflows for automating the deployment and management of AWS infrastructure using Terraform and Terragrunt.

## Overview

The CI/CD pipeline provides automated testing, validation, planning, and deployment of infrastructure changes across multiple environments (dev, staging, prod).

## Pipeline Structure

### Main Workflow: `terraform-ci.yml`

The primary workflow file [`terraform-ci.yml`](workflows/terraform-ci.yml) defines the complete CI/CD pipeline with the following jobs:

1. **terraform-validate** - Validates Terraform configuration syntax and formatting
2. **terraform-plan** - Generates Terraform execution plans (for PRs)
3. **terraform-apply** - Applies infrastructure changes (for main branch)
4. **security-scan** - Performs security scanning with Checkov
5. **notify** - Sends notifications to Slack

## Workflow Triggers

### Pull Requests
- Triggers on PR creation/updates to `main` branch
- Runs validation, planning, and security scanning
- Provides plan output for review

### Push to Main Branch
- Triggers on pushes to `main` branch
- Runs full validation, planning, and application
- Deploys changes to infrastructure

## Environment Configuration

### Required Secrets

Add these secrets to your GitHub repository settings:

```bash
# AWS Configuration
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole

# Slack Notifications (Optional)
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

### Environment Variables

The pipeline uses these environment variables:

```yaml
env:
  AWS_REGION: us-east-1
  TF_VERSION: "1.6.0"
  TERRAGRUNT_VERSION: "0.51.1"
```

## Job Descriptions

### 1. terraform-validate

**Purpose**: Validates Terraform configuration before any changes are applied

**Steps**:
- Checkout repository
- Setup Terraform
- Run `terraform fmt -check -recursive` (formatting check)
- Run `terraform init -backend=false` (initialization without backend)
- Run `terraform validate` (syntax and configuration validation)

**Output**: Pass/Fail status based on validation results

### 2. terraform-plan

**Purpose**: Generates Terraform execution plans for review

**Triggers**: Pull requests to main branch

**Steps**:
- Checkout repository
- Setup AWS credentials using OIDC
- Setup Terraform and Terragrunt
- Run `terragrunt plan -out=terraform.tfplan`
- Upload plan artifact for review

**Output**: Terraform plan file as artifact

### 3. terraform-apply

**Purpose**: Applies infrastructure changes to AWS

**Triggers**: Pushes to main branch only

**Steps**:
- Checkout repository
- Setup AWS credentials using OIDC
- Setup Terraform and Terragrunt
- Download plan artifact
- Run `terragrunt apply -auto-approve terraform.tfplan`

**Output**: Applied infrastructure changes

### 4. security-scan

**Purpose**: Performs security scanning using Checkov

**Steps**:
- Checkout repository
- Run Checkov security scan
- Generate SARIF report
- Upload results to GitHub Security tab

**Output**: Security scan results and alerts

### 5. notify

**Purpose**: Sends notifications about pipeline status

**Steps**:
- Send Slack notification with pipeline status
- Include success/failure information

**Output**: Slack message with pipeline status

## IAM Roles and Permissions

### 1. GitHub Actions OIDC Role

Create an IAM role that GitHub Actions can assume using OpenID Connect (OIDC).

#### Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORGANIZATION/REPOSITORY:*"
        }
      }
    }
  ]
}
```

#### Required Permissions

Attach these managed policies to the role:

```json
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
        "ec2:Describe*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
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
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateVpcPeeringConnection",
        "ec2:AcceptVpcPeeringConnection",
        "ec2:DeleteVpcPeeringConnection",
        "ec2:ModifyVpcPeeringConnectionOptions"
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
        "eks:ListClusters",
        "eks:ListNodegroups",
        "eks:AccessKubernetesApi"
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
        "rds:ModifyDBSubnetGroup"
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
        "apigateway:PATCH"
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
        "route53:ChangeResourceRecordSets"
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
        "organizations:DescribeOrganization",
        "organizations:ListAccounts",
        "organizations:DescribeAccount",
        "organizations:ListOrganizationalUnitsForParent",
        "organizations:DescribeOrganizationalUnit"
      ],
      "Resource": "*"
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
```

### 2. Environment-Specific Roles

For each environment account, create roles that the main GitHub Actions role can assume:

#### Dev Account Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "dev-environment"
        }
      }
    }
  ]
}
```

#### Staging Account Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "staging-environment"
        }
      }
    }
  ]
}
```

#### Production Account Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "production-environment"
        }
      }
    }
  ]
}
```

## Security Best Practices

### 1. Least Privilege Access

- Grant only necessary permissions for each role
- Use resource-specific ARNs where possible
- Regularly review and update permissions

### 2. OIDC Integration

- Use OpenID Connect for authentication instead of long-lived credentials
- Configure proper trust relationships
- Use conditions to restrict access

### 3. Environment Isolation

- Separate roles for each environment
- Use different external IDs for each environment
- Implement cross-account access controls

### 4. Monitoring and Auditing

- Enable CloudTrail for API logging
- Monitor role usage and access patterns
- Set up alerts for unusual activity

## Usage Examples

### Running the Pipeline

1. **Create a Pull Request**:
   ```bash
   git checkout -b feature/new-infrastructure
   # Make changes to Terraform files
   git add .
   git commit -m "Add new infrastructure"
   git push origin feature/new-infrastructure
   # Create PR via GitHub UI
   ```

2. **Merge to Main**:
   ```bash
   # After PR approval, merge to main branch
   # Pipeline will automatically deploy changes
   ```

### Manual Deployment

```bash
# Deploy to specific environment
cd environments/dev/shared
terragrunt apply

# Deploy all environments
make dev-apply
```

### Troubleshooting

#### Common Issues

1. **Permission Denied**:
   - Check IAM role permissions
   - Verify OIDC trust relationship
   - Ensure correct external ID

2. **Terraform State Lock**:
   ```bash
   # Check if state is locked
   aws dynamodb get-item --table-name terraform-locks --key '{"LockID":{"S":"path/to/state"}}'
   
   # Force unlock (use with caution)
   terragrunt force-unlock LOCK_ID
   ```

3. **Plan Failures**:
   - Check Terraform syntax
   - Verify AWS credentials
   - Review resource dependencies

## Monitoring and Notifications

### Slack Integration

Configure Slack notifications by:

1. Creating a Slack webhook URL
2. Adding it as a repository secret: `SLACK_WEBHOOK`
3. Pipeline will send notifications on job completion

### GitHub Security Tab

Security scan results appear in the GitHub Security tab:
- View Checkov scan results
- Track security findings
- Monitor compliance status

## Customization

### Adding New Jobs

To add a new job to the pipeline:

1. Add job definition to `terraform-ci.yml`
2. Define required permissions in IAM roles
3. Test the job in a development environment

### Environment-Specific Configuration

Create environment-specific workflow files:

```yaml
# .github/workflows/terraform-staging.yml
name: Terraform Staging

on:
  push:
    branches: [ staging ]

jobs:
  deploy-staging:
    # Environment-specific deployment logic
```

## Support

For issues or questions:

1. Check the [troubleshooting section](#troubleshooting)
2. Review GitHub Actions logs
3. Check AWS CloudTrail for API calls
4. Contact the infrastructure team