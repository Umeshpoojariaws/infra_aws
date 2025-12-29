# IAM Setup Guide for GitHub Actions CI/CD

This guide provides step-by-step instructions for creating the necessary IAM roles and policies for the GitHub Actions CI/CD pipeline.

## Overview

The setup involves creating:
1. **OIDC Provider** in AWS for GitHub authentication
2. **Main GitHub Actions Role** with broad permissions
3. **Environment-specific roles** for cross-account access
4. **Supporting policies** for security scanning and read-only access

## Prerequisites

- AWS CLI installed and configured
- Administrator access to AWS account
- GitHub repository URL

## Step 1: Create OIDC Provider for GitHub

### Using AWS CLI

```bash
# Create OIDC provider for GitHub
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Using AWS Console

1. Go to IAM Console
2. Navigate to **Identity providers** > **Add provider**
3. Choose **OpenID Connect**
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Click **Add provider**

## Step 2: Create GitHub Actions Role

### Using AWS CLI

```bash
# Create trust policy file
cat > github-actions-trust-policy.json << 'EOF'
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
EOF

# Create the role
aws iam create-role \
  --role-name GitHubActionsOIDCRole \
  --assume-role-policy-document file://github-actions-trust-policy.json

# Create permissions policy file
cat > github-actions-permissions-policy.json << 'EOF'
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
EOF

# Attach the policy
aws iam put-role-policy \
  --role-name GitHubActionsOIDCRole \
  --policy-name GitHubActionsPermissions \
  --policy-document file://github-actions-permissions-policy.json
```

### Using AWS Console

1. Go to IAM Console
2. Navigate to **Roles** > **Create role**
3. Choose **Web identity**
4. Provider: `token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Click **Next: Permissions**
7. Create a new policy with the permissions above
8. Name the role: `GitHubActionsOIDCRole`
9. Click **Create role**

## Step 3: Create Environment-Specific Roles

### For Dev Account

```bash
# Create trust policy for dev account
cat > dev-account-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsOIDCRole"
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
EOF

# Create the role in dev account
aws iam create-role \
  --role-name GitHubActionsDevRole \
  --assume-role-policy-document file://dev-account-trust-policy.json

# Attach administrator policy (or create custom policy)
aws iam attach-role-policy \
  --role-name GitHubActionsDevRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### For Staging Account

```bash
# Create trust policy for staging account
cat > staging-account-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsOIDCRole"
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
EOF

# Create the role in staging account
aws iam create-role \
  --role-name GitHubActionsStagingRole \
  --assume-role-policy-document file://staging-account-trust-policy.json

# Attach administrator policy
aws iam attach-role-policy \
  --role-name GitHubActionsStagingRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### For Production Account

```bash
# Create trust policy for production account
cat > prod-account-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsOIDCRole"
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
EOF

# Create the role in production account
aws iam create-role \
  --role-name GitHubActionsProdRole \
  --assume-role-policy-document file://prod-account-trust-policy.json

# Attach administrator policy
aws iam attach-role-policy \
  --role-name GitHubActionsProdRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## Step 4: Configure GitHub Repository Secrets

### Using GitHub CLI

```bash
# Set the AWS role ARN
gh secret set AWS_ROLE_ARN -b"arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsOIDCRole"

# Set Slack webhook (optional)
gh secret set SLACK_WEBHOOK -b"https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
```

### Using GitHub Web Interface

1. Go to your repository on GitHub
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add the following secrets:
   - `AWS_ROLE_ARN`: `arn:aws:iam::MAIN_ACCOUNT_ID:role/GitHubActionsOIDCRole`
   - `SLACK_WEBHOOK`: (optional) Your Slack webhook URL

## Step 5: Update Workflow Configuration

Update the [`terraform-ci.yml`](workflows/terraform-ci.yml) file with your specific account IDs and external IDs:

```yaml
env:
  AWS_REGION: us-east-1
  TF_VERSION: "1.6.0"
  TERRAGRUNT_VERSION: "0.51.1"

# In the setup-aws-credentials step:
- name: Setup AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsOIDCRole
    role-session-name: GitHubActions-${{ github.run_number }}
    aws-region: ${{ env.AWS_REGION }}
```

## Step 6: Test the Setup

### Create a Test Workflow

```yaml
name: Test GitHub Actions Setup
on:
  workflow_dispatch:

jobs:
  test-aws-connection:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Setup AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsOIDCRole
        role-session-name: TestSession
        aws-region: us-east-1

    - name: Test AWS CLI
      run: aws sts get-caller-identity
```

### Run the Test

1. Commit and push the test workflow
2. Trigger it manually from GitHub Actions tab
3. Check the logs to verify AWS authentication works

## Security Best Practices

### 1. Principle of Least Privilege

Instead of using `AdministratorAccess`, create custom policies with minimal required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    }
  ]
}
```

### 2. Use Conditions for Additional Security

Add conditions to trust policies:

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
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:ref": "refs/heads/main"
        }
      }
    }
  ]
}
```

### 3. Enable MFA for Sensitive Operations

For production deployments, require MFA:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam::ACCOUNT_ID:role/GitHubActionsProdRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **"The provided id_token is not valid"**
   - Check OIDC provider configuration
   - Verify GitHub repository URL in trust policy

2. **"AccessDenied" errors**
   - Check role permissions
   - Verify trust policy conditions
   - Ensure correct external ID for cross-account roles

3. **"Cannot parse sub as a valid ARN"**
   - Check trust policy format
   - Verify GitHub Actions workflow configuration

### Debug Commands

```bash
# Check OIDC provider
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

# Check role trust policy
aws iam get-role --role-name GitHubActionsOIDCRole

# Test assume role
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsOIDCRole \
  --role-session-name test \
  --web-identity-token $TOKEN
```

## Cleanup

To remove all created resources:

```bash
# Delete roles
aws iam delete-role --role-name GitHubActionsOIDCRole
aws iam delete-role --role-name GitHubActionsDevRole
aws iam delete-role --role-name GitHubActionsStagingRole
aws iam delete-role --role-name GitHubActionsProdRole

# Delete OIDC provider
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

# Delete policies
aws iam delete-role-policy --role-name GitHubActionsOIDCRole --policy-name GitHubActionsPermissions
```

This completes the IAM setup for GitHub Actions CI/CD pipeline. The setup provides secure, role-based access to AWS resources while maintaining the principle of least privilege.