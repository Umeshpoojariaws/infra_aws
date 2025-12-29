# 🧹 Manual Cleanup Guide

This guide helps you manually clean up AWS resources that cannot be deleted via Terraform.

## 🚨 **Important Notes**

- **AWS Organizations accounts cannot be deleted via API** once created
- **Some resources require manual cleanup via AWS Console**
- **This is a one-time manual process** - after cleanup, the beginner's exercise will work perfectly

## 📋 **Resources That Need Manual Cleanup**

### 1. **AWS Organizations Accounts**
**Cannot be deleted via API** - must be removed manually via AWS Console.

**Accounts to remove:**
- `138412911194` (dev-app)
- `130361465823` (dev-ml)

### 2. **S3 Bucket**
**Already exists** - can be kept or deleted manually.

**Bucket name:** `terraform-state-082291634188`

### 3. **DynamoDB Table**
**Already exists** - can be kept or deleted manually.

**Table name:** `terraform-locks`

## 🛠️ **Manual Cleanup Steps**

### **Step 1: Remove AWS Organizations Accounts**

1. **Sign in to AWS Organizations Console**
   - Go to: https://console.aws.amazon.com/organizations/
   - Sign in with your **management account** credentials

2. **Navigate to Accounts Section**
   - In the left sidebar, click **"Accounts"**

3. **Remove dev-app Account**
   - Find account `138412911194` (dev-app)
   - Click the checkbox next to it
   - Click **"Remove accounts"** button
   - **Important**: You will be prompted to enter missing information
   - Follow the prompts to complete removal

4. **Remove dev-ml Account**
   - Find account `130361465823` (dev-ml)
   - Click the checkbox next to it
   - Click **"Remove accounts"** button
   - **Important**: You will be prompted to enter missing information
   - Follow the prompts to complete removal

### **Step 2: Clean Up S3 Bucket (Optional)**

**If you want to start fresh:**

1. **Go to S3 Console**
   - Navigate to: https://console.aws.amazon.com/s3/
   - Find bucket: `terraform-state-082291634188`

2. **Delete Bucket Contents**
   - Click on the bucket name
   - Select all objects and delete them
   - Empty the bucket completely

3. **Delete the Bucket**
   - With the bucket empty, click **"Delete"**
   - Confirm deletion

**If you want to keep the bucket:**
- No action needed - the bucket will be reused

### **Step 3: Clean Up DynamoDB Table (Optional)**

**If you want to start fresh:**

1. **Go to DynamoDB Console**
   - Navigate to: https://console.aws.amazon.com/dynamodb/
   - Find table: `terraform-locks`

2. **Delete the Table**
   - Select the table
   - Click **"Delete table"**
   - Confirm deletion

**If you want to keep the table:**
- No action needed - the table will be reused

## 🔄 **Alternative: Skip Manual Cleanup**

If manual cleanup seems complex, you can **skip it entirely** and use the existing resources:

### **Option 1: Use Existing Accounts**
```bash
# Check existing accounts
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email}' --output table

# Use these existing account IDs in your configuration
```

### **Option 2: Modify Configuration**
Update the beginner's exercise to use the existing accounts instead of creating new ones.

## 🎯 **After Cleanup**

Once manual cleanup is complete:

1. **Run the beginner's exercise**
2. **All resources will be created fresh**
3. **No more conflicts or errors**
4. **Perfect learning experience**

## ⚠️ **Important Reminders**

- **Account removal is one-time only** - after removal, you can create new accounts
- **Bucket and table cleanup is optional** - existing resources will work fine
- **Take your time** - follow AWS Console prompts carefully
- **Document account IDs** if you choose to keep existing accounts

## 🆘 **Need Help?**

If you encounter issues during manual cleanup:

1. **Check AWS Documentation**: https://docs.aws.amazon.com/organizations/
2. **AWS Support**: Contact AWS Support for account removal issues
3. **Skip Cleanup**: Use the existing resources instead of cleaning up

## 🎉 **Success!**

After manual cleanup (or choosing to use existing resources), you'll have a clean environment ready for the beginner's AWS multi-account infrastructure exercise!