#!/bin/bash

# Script to handle existing AWS resources and prepare for clean Terraform deployment
# This script helps resolve common issues with existing accounts and resources

set -e

echo "🔧 AWS Resource Handling Script"
echo "==============================="

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 Main Account ID: $ACCOUNT_ID"

# Check for existing DynamoDB table
echo ""
echo "🔍 Checking for existing DynamoDB table..."
if aws dynamodb describe-table --table-name terraform-locks > /dev/null 2>&1; then
    echo "✅ DynamoDB table 'terraform-locks' already exists"
    echo "   Terraform will ignore changes to this table"
else
    echo "❌ DynamoDB table 'terraform-locks' does not exist"
    echo "   Creating table..."
    aws dynamodb create-table \
        --table-name terraform-locks \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
    
    # Wait for table creation
    aws dynamodb wait table-exists --table-name terraform-locks
    echo "✅ DynamoDB table created successfully"
fi

# Check for existing S3 bucket
echo ""
echo "🔍 Checking for existing S3 bucket..."
BUCKET_NAME="terraform-state-$ACCOUNT_ID"
if aws s3 ls "s3://$BUCKET_NAME" > /dev/null 2>&1; then
    echo "✅ S3 bucket '$BUCKET_NAME' already exists"
    echo "   Checking bucket configuration..."
    
    # Check versioning
    VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query Status --output text 2>/dev/null || echo "Disabled")
    if [ "$VERSIONING" = "Enabled" ]; then
        echo "   ✅ Versioning is enabled"
    else
        echo "   ⚠️  Enabling versioning..."
        aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    fi
    
    # Check encryption
    ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" 2>/dev/null || echo "No encryption")
    if [[ "$ENCRYPTION" == *"AES256"* ]] || [[ "$ENCRYPTION" == *"aws:kms"* ]]; then
        echo "   ✅ Encryption is configured"
    else
        echo "   ⚠️  Configuring encryption..."
        aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{
          "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
        }'
    fi
    
    # Check public access block
    PUBLIC_ACCESS=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --query 'PublicAccessBlockConfiguration' --output text 2>/dev/null || echo "No public access block")
    if [[ "$PUBLIC_ACCESS" == *"true"* ]]; then
        echo "   ✅ Public access block is configured"
    else
        echo "   ⚠️  Configuring public access block..."
        aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    fi
else
    echo "❌ S3 bucket '$BUCKET_NAME' does not exist"
    echo "   Creating bucket..."
    aws s3 mb "s3://$BUCKET_NAME"
    
    # Configure bucket
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{
      "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }'
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    echo "✅ S3 bucket created and configured successfully"
fi

# Check for existing AWS Organization
echo ""
echo "🔍 Checking for existing AWS Organization..."
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || echo "")
if [ -n "$ORG_ID" ] && [ "$ORG_ID" != "None" ]; then
    echo "✅ AWS Organization exists: $ORG_ID"
    
    # List existing accounts
    echo "📋 Existing accounts in organization:"
    aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email}' --output table
    
    # Check for specific old accounts that might cause issues
    OLD_ACCOUNTS=("138412911194" "130361465823")
    for account in "${OLD_ACCOUNTS[@]}"; do
        if aws organizations describe-account --account-id "$account" > /dev/null 2>&1; then
            echo "⚠️  Old account $account found - may need manual cleanup"
            echo "   Run: ./scripts/cleanup-old-accounts.sh for cleanup instructions"
        fi
    done
else
    echo "❌ No AWS Organization found"
    echo "   Organization will be created during Terraform apply"
fi

# Check for existing IAM roles and policies
echo ""
echo "🔍 Checking for existing IAM resources..."
if aws iam get-role --role-name GitHubActionsOIDCRole > /dev/null 2>&1; then
    echo "✅ GitHubActionsOIDCRole already exists"
else
    echo "❌ GitHubActionsOIDCRole does not exist"
    echo "   Role will be created during Terraform apply"
fi

if aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/GitHubActionsPermissions" > /dev/null 2>&1; then
    echo "✅ GitHubActionsPermissions policy already exists"
else
    echo "❌ GitHubActionsPermissions policy does not exist"
    echo "   Policy will be created during Terraform apply"
fi

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" > /dev/null 2>&1; then
    echo "✅ GitHub OIDC provider already exists"
else
    echo "❌ GitHub OIDC provider does not exist"
    echo "   OIDC provider will be created during Terraform apply"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Run 'terraform init' in the global directory"
echo "2. Run 'terraform plan' to see what will be created/updated"
echo "3. Run 'terraform apply' to deploy the infrastructure"
echo ""
echo "💡 Note: Existing resources will be managed by Terraform"
echo "   but won't be recreated unless necessary."