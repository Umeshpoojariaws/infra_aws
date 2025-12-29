#!/bin/bash

# Script to reset Terraform state and remove problematic resources
# This script helps resolve issues with accounts that cannot be deleted via API

set -e

echo "🔄 Resetting Terraform State"
echo "=========================="

# Check if we're in the right directory
if [ ! -f "global/organization.tf" ]; then
    echo "❌ Error: Run this script from the repository root directory"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

echo "📋 Checking Terraform state..."

# Check if state file exists
if [ ! -f "global/.terraform/terraform.tfstate" ]; then
    echo "✅ No existing Terraform state found - starting fresh!"
    echo "   This is perfect for a clean deployment."
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Run 'terraform init' to initialize"
    echo "2. Run 'terraform plan' to see what will be created"
    echo "3. Run 'terraform apply' to deploy the infrastructure"
    echo ""
    echo "💡 Note: This will create all resources from scratch."
    exit 0
fi

echo "📋 Current Terraform state:"
terraform state list

echo ""
echo "⚠️  Removing problematic resources from Terraform state..."
echo "   These resources cannot be deleted via API and must be handled manually."

# Remove old accounts that cannot be deleted via API
echo "Removing old accounts from state..."
terraform state rm aws_organizations_account.dev_app 2>/dev/null || echo "   dev_app account not in state"
terraform state rm aws_organizations_account.dev_ml 2>/dev/null || echo "   dev_ml account not in state"

# Remove other resources that may have issues
echo "Removing other problematic resources from state..."
terraform state rm aws_organizations_organizational_unit.dev 2>/dev/null || echo "   dev OU not in state"
terraform state rm aws_organizations_organizational_unit.staging 2>/dev/null || echo "   staging OU not in state"
terraform state rm aws_organizations_organizational_unit.prod 2>/dev/null || echo "   prod OU not in state"
terraform state rm aws_organizations_organizational_unit.environments 2>/dev/null || echo "   environments OU not in state"
terraform state rm aws_organizations_organization.root 2>/dev/null || echo "   organization not in state"
terraform state rm aws_organizations_policy.scp_restrictions 2>/dev/null || echo "   SCP policy not in state"
terraform state rm aws_organizations_policy_attachment.scp_to_environments 2>/dev/null || echo "   SCP attachment not in state"

# Remove IAM resources that may have issues
terraform state rm aws_iam_openid_connect_provider.github 2>/dev/null || echo "   OIDC provider not in state"
terraform state rm aws_iam_policy.github_actions_permissions 2>/dev/null || echo "   GitHub Actions policy not in state"
terraform state rm aws_iam_role.github_actions 2>/dev/null || echo "   GitHub Actions role not in state"
terraform state rm aws_iam_role_policy_attachment.github_actions_permissions 2>/dev/null || echo "   GitHub Actions role attachment not in state"

# Remove S3 and DynamoDB resources that may have issues
terraform state rm aws_s3_bucket.terraform_state 2>/dev/null || echo "   S3 bucket not in state"
terraform state rm aws_s3_bucket_versioning.terraform_state 2>/dev/null || echo "   S3 versioning not in state"
terraform state rm aws_s3_bucket_server_side_encryption_configuration.terraform_state 2>/dev/null || echo "   S3 encryption not in state"
terraform state rm aws_s3_bucket_public_access_block.terraform_state 2>/dev/null || echo "   S3 public access block not in state"
terraform state rm aws_dynamodb_table.terraform_locks 2>/dev/null || echo "   DynamoDB table not in state"

echo ""
echo "✅ State reset complete!"
echo ""
echo "🎯 Next Steps:"
echo "1. Run 'terraform init' to re-initialize"
echo "2. Run 'terraform plan' to see what will be created"
echo "3. Run 'terraform apply' to deploy the infrastructure"
echo ""
echo "💡 Note: This will recreate all resources, but existing accounts"
echo "   will be managed by Terraform without trying to delete them."
echo ""
echo "⚠️  Important: If you have existing accounts that you want to keep,"
echo "   make sure to update the email addresses in organization.tf to"
echo "   match your existing accounts, or they will be recreated."