#!/bin/bash

# Cleanup script for removing old AWS Organization accounts
# This script helps resolve Terraform deletion errors

set -e

echo "🔍 AWS Organization Cleanup Script"
echo "=================================="

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Get organization ID
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || echo "")
if [ -z "$ORG_ID" ]; then
    echo "❌ Not in an AWS Organization or no permissions"
    exit 1
fi

echo "📋 Organization ID: $ORG_ID"

# List accounts that need manual cleanup
echo ""
echo "⚠️  Accounts that need manual removal from AWS Console:"
echo "   These accounts cannot be deleted via API due to AWS restrictions."
echo ""

# Check for specific account IDs that were in the old configuration
echo "   Account IDs to remove manually:"
echo "   - 138412911194 (dev-app)"
echo "   - 130361465823 (dev-ml)"
echo ""

echo "🔧 Manual Cleanup Steps:"
echo "1. Go to AWS Organizations Console: https://console.aws.amazon.com/organizations/"
echo "2. Navigate to 'Accounts' section"
echo "3. Find and select the accounts listed above"
echo "4. Click 'Remove account' for each"
echo "5. Follow the prompts to complete removal"
echo ""

echo "📝 Important Notes:"
echo "- You must sign in to each account using the AWS Organizations console"
echo "- Each account will prompt you to enter missing information"
echo "- This is a one-time manual process required by AWS"
echo ""

echo "✅ After completing manual cleanup, run:"
echo "   terraform apply -var='main_account_id=\$AWS_ACCOUNT_ID' \\"
echo "                -var='github_org=\$GITHUB_ORG' \\"
echo "                -var='github_repo=\$GITHUB_REPO'"
echo ""

echo "💡 Alternative: Skip cleanup and use existing accounts"
echo "   If you prefer not to remove accounts, you can:"
echo "   1. Keep the existing accounts"
echo "   2. Update the beginner's exercise to use them"
echo "   3. Skip the account creation step"
echo ""

echo "🎯 Recommended: Complete manual cleanup for clean setup"