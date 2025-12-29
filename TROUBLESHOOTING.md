# 🛠️ Troubleshooting Guide

This guide helps you resolve common issues when setting up the AWS multi-account infrastructure.

## 📋 Table of Contents

1. [AWS Account and Permission Issues](#aws-account-and-permission-issues)
2. [Terraform Configuration Problems](#terraform-configuration-problems)
3. [GitHub Actions and CI/CD Issues](#github-actions-and-cicd-issues)
4. [Resource Conflicts and State Management](#resource-conflicts-and-state-management)
5. [Network and Connectivity Problems](#network-and-connectivity-problems)

---

## 🔐 AWS Account and Permission Issues

### **Problem: "Unable to locate credentials"**
```bash
aws: error: argument command: Invalid choice, valid choices are:
```

**Solution:**
```bash
# Configure AWS CLI with your credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

### **Problem: "User is not authorized to perform..."**
```bash
Error: UnauthorizedOperation: You are not authorized to perform this operation
```

**Solution:**
1. Ensure your IAM user has `AdministratorAccess` policy attached
2. Check that you're using the correct AWS account
3. Verify your credentials are for the management account (not a member account)

### **Problem: "Account limit exceeded"**
```bash
Error: Account limit exceeded for account: 123456789012
```

**Solution:**
- AWS has default limits on the number of accounts per organization
- Request a limit increase from AWS Support
- Or use existing accounts instead of creating new ones

---

## 🔧 Terraform Configuration Problems

### **Problem: "Provider configuration not present"**
```bash
Error: Provider configuration for aws is present but terraform init has not yet been run
```

**Solution:**
```bash
# Initialize Terraform in each directory
terraform init

# If using backend configuration, ensure backend.tf is present
```

### **Problem: "Variable not set"**
```bash
Error: No value for required variable "main_account_id"
```

**Solution:**
```bash
# Set variables via command line
terraform apply -var="main_account_id=123456789012" \
               -var="github_org=myorg" \
               -var="github_repo=myrepo"

# Or create terraform.tfvars file
echo 'main_account_id = "123456789012"' > terraform.tfvars
echo 'github_org = "myorg"' >> terraform.tfvars
echo 'github_repo = "myrepo"' >> terraform.tfvars
```

### **Problem: "Resource already exists"**
```bash
Error: BucketAlreadyOwnedByYou: Your previous request to create the named bucket succeeded
```

**Solution:**
- Use a unique bucket name (include timestamp or random suffix)
- Or use `lifecycle { ignore_changes = [...] }` to ignore existing resources

---

## 🚀 GitHub Actions and CI/CD Issues

### **Problem: "OIDC provider not found"**
```bash
Error: Invalid OpenID Connect Provider ARN
```

**Solution:**
1. Ensure the OIDC provider is created in the main account
2. Check that the GitHub Actions role has the correct trust policy
3. Verify the GitHub repository and organization names match

### **Problem: "Access denied" in GitHub Actions**
```bash
Error: AccessDenied: User: arn:aws:sts::123456789012:assumed-role/GitHubActionsOIDCRole/... is not authorized to perform: organizations:DescribeOrganization
```

**Solution:**
1. Check that the GitHub Actions role has the correct permissions policy attached
2. Verify the trust policy allows the correct GitHub repository
3. Ensure the role is in the management account

### **Problem: "Terraform state not found"**
```bash
Error: Failed to get state: state data in S3 does not have the correct format
```

**Solution:**
1. Ensure the S3 bucket exists and has the correct name
2. Check that the DynamoDB table exists for state locking
3. Verify the backend configuration matches the actual resources

---

## 🔄 Resource Conflicts and State Management

### **Problem: "State lock acquired by another process"**
```bash
Error: Error acquiring the state lock
```

**Solution:**
```bash
# Force unlock if you're sure no one else is using it
terraform force-unlock LOCK_ID

# Or wait for the other process to complete
```

### **Problem: "Account cannot be deleted"**
```bash
Error: The member account is missing one or more of the prerequisites required to operate as a standalone account
```

**Solution:**
1. **Manual removal via AWS Console:**
   - Go to AWS Organizations Console
   - Navigate to Accounts section
   - Select the account and click "Remove account"
   - Follow the prompts to complete removal

2. **Use existing accounts:**
   - Skip account creation and use existing accounts
   - Update the configuration to reference existing account IDs

### **Problem: "Resource already exists"**
```bash
Error: creating AWS DynamoDB Table (terraform-locks): Table already exists: terraform-locks
```

**Solution:**
```bash
# Check if table exists
aws dynamodb describe-table --table-name terraform-locks

# If it exists, use lifecycle ignore_changes
# Or delete it manually if safe to do so
aws dynamodb delete-table --table-name terraform-locks
```

---

## 🌐 Network and Connectivity Problems

### **Problem: "VPC peering connection failed"**
```bash
Error: VPC peering connection cannot be established
```

**Solution:**
1. Ensure VPC CIDR blocks don't overlap
2. Check that both accounts have the necessary permissions
3. Verify that the VPCs exist and are in the correct regions

### **Problem: "EKS cluster creation failed"**
```bash
Error: Unsupported availability zone
```

**Solution:**
1. Check that the selected region supports EKS
2. Verify that the subnets are in different AZs
3. Ensure the VPC has the required CIDR block size

### **Problem: "RDS connection timeout"**
```bash
Error: Cannot connect to database
```

**Solution:**
1. Check that the security groups allow the correct traffic
2. Verify that the database subnet group is configured correctly
3. Ensure the database is in the correct VPC

---

## 🚨 Emergency Recovery

### **Complete State Loss**
If you lose your Terraform state:

1. **Recreate resources manually** using AWS Console
2. **Import existing resources** into Terraform:
   ```bash
   terraform import aws_s3_bucket.my_bucket my-bucket-name
   terraform import aws_dynamodb_table.my_table my-table-name
   ```

3. **Rebuild state file** from scratch if needed

### **Accidental Resource Deletion**
If you accidentally delete critical resources:

1. **Check AWS CloudTrail** for recent API calls
2. **Use AWS Backup** if enabled
3. **Recreate resources** using Terraform
4. **Import existing resources** back into state

### **Permission Lockout**
If you lose access to your AWS account:

1. **Use AWS Organizations** to regain access
2. **Contact AWS Support** for account recovery
3. **Use root account credentials** if available

---

## 📞 Getting Help

### **AWS Support**
- [AWS Support Center](https://console.aws.amazon.com/support/)
- [AWS Documentation](https://docs.aws.amazon.com/)
- [AWS Forums](https://forums.aws.amazon.com/)

### **Terraform Support**
- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [Terraform Community](https://discuss.hashicorp.com/c/terraform-core/)
- [Terraform Registry](https://registry.terraform.io/)

### **GitHub Actions Support**
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Community Forum](https://github.community/c/code-to-cloud/github-actions/41)
- [GitHub Support](https://support.github.com/)

---

## 🧪 Testing and Validation

### **Quick Health Check**
Run this script to verify your setup:

```bash
#!/bin/bash
echo "🔍 Infrastructure Health Check"
echo "=============================="

# Check AWS CLI
echo "AWS CLI: $(aws --version 2>&1 | head -1)"
aws sts get-caller-identity --query Account --output text

# Check Terraform
echo "Terraform: $(terraform --version | head -1)"

# Check kubectl
echo "kubectl: $(kubectl version --client --short 2>&1)"

# Check S3 bucket
aws s3 ls s3://terraform-state-$(aws sts get-caller-identity --query Account --output text) 2>/dev/null && echo "✅ S3 bucket exists" || echo "❌ S3 bucket missing"

# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-locks 2>/dev/null && echo "✅ DynamoDB table exists" || echo "❌ DynamoDB table missing"

echo "Health check complete!"
```

### **Common Validation Commands**
```bash
# List AWS accounts in organization
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id}' --output table

# Check EKS clusters
aws eks list-clusters --region us-east-1

# Check RDS instances
aws rds describe-db-instances --query 'DBInstances[].{Name:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table

# Check API Gateway
aws apigateway get-rest-apis --query 'items[].{Name:name,Id:id}' --output table
```

---

**Remember**: When in doubt, check the logs, verify your permissions, and consult the official documentation. Most issues can be resolved by carefully reading error messages and following the troubleshooting steps above.