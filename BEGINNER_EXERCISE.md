# 🚀 Complete Beginner's AWS Multi-Account Infrastructure Exercise

**Transform from zero AWS experience to deploying professional multi-account infrastructure in 4 hours!**

## 📋 Overview

This comprehensive exercise guides complete beginners through setting up a production-ready AWS multi-account infrastructure using Terraform and GitHub Actions. You'll learn AWS Organizations, Terraform, CI/CD, and Kubernetes deployment.

**Time Required:** 4 hours (broken into 5 manageable phases)
**Prerequisites:** None! Just a computer and willingness to learn.

## 🎯 Learning Outcomes

By the end of this exercise, you will:
- ✅ Understand AWS Organizations and multi-account architecture
- ✅ Master Terraform for Infrastructure as Code
- ✅ Set up GitHub Actions for CI/CD automation
- ✅ Deploy Kubernetes applications across environments
- ✅ Implement professional cloud infrastructure practices

## 📚 Phase-by-Phase Guide

### 📝 **Phase 1: AWS Account Setup** (30 minutes)

#### Step 1: Create AWS Account
1. Go to [aws.amazon.com](https://aws.amazon.com/) and click "Create an AWS Account"
2. Follow the sign-up process (you'll need a credit card for verification)
3. Complete identity verification (usually takes a few minutes)
4. Set up billing alerts to avoid unexpected charges

#### Step 2: Create IAM User with Administrator Access
```bash
# In AWS Console:
# 1. Go to IAM service
# 2. Click "Users" → "Add user"
# 3. Name: "terraform-admin"
# 4. Select "Programmatic access" and "AWS Management Console access"
# 5. Attach existing policies: AdministratorAccess
# 6. Create user and save credentials securely
```

#### Step 3: Install Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip
unzip terraform_1.9.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify installations
aws --version
terraform --version
kubectl version --client
```

#### Step 4: Configure AWS CLI
```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region (us-east-1), and output format (json)
```

**✅ Phase 1 Complete!** You now have a working AWS account with proper IAM setup.

---

### 🛠️ **Phase 2: Development Environment Setup** (45 minutes)

#### Step 1: Clone and Explore the Repository
```bash
# Clone the infrastructure repository
git clone https://github.com/your-username/aws-multi-account-infra.git
cd aws-multi-account-infra

# Explore the structure
ls -la
tree -L 3  # if tree is installed, otherwise use find
```

#### Step 2: Set Up GitHub Repository
1. Create a new GitHub repository (private recommended for learning)
2. Push the infrastructure code:
```bash
git remote add origin https://github.com/your-username/your-repo.git
git branch -M main
git push -u origin main
```

#### Step 3: Configure Environment Variables
```bash
# Create .env file for local development
cat > .env << EOF
# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=default

# GitHub Configuration
GITHUB_ORG=your-username
GITHUB_REPO=your-repo

# Account IDs (will be filled after Phase 3)
MAIN_ACCOUNT_ID=your-main-account-id
DEV_SHARED_ACCOUNT_ID=
STAGING_SHARED_ACCOUNT_ID=
PROD_SHARED_ACCOUNT_ID=
EOF

# Load environment variables
source .env
```

#### Step 4: Test AWS Access
```bash
# Test AWS CLI access
aws sts get-caller-identity

# Expected output: Your account ID and user ARN
```

**✅ Phase 2 Complete!** Your development environment is ready.

---

### 🏗️ **Phase 3: Infrastructure as Code** (60 minutes)

#### Step 1: Handle Existing Resources (NEW - Critical Step!)
Before running Terraform, check for existing resources:

```bash
# Run the resource handling script
chmod +x scripts/handle-existing-resources.sh
./scripts/handle-existing-resources.sh
```

This script will:
- ✅ Check for existing DynamoDB table and S3 bucket
- ✅ Configure them properly if they exist
- ✅ List existing AWS accounts in your organization
- ✅ Check for existing IAM roles and policies
- ✅ Provide guidance on what to expect

#### Step 2: Reset Terraform State (If Needed)
If you encounter issues with existing Terraform state:

```bash
# Run the state reset script
chmod +x scripts/reset-terraform-state.sh
./scripts/reset-terraform-state.sh
```

This script will:
- ✅ Remove problematic resources from Terraform state
- ✅ Allow clean re-deployment without conflicts
- ✅ Preserve existing AWS resources

#### Step 3: Work with Existing Accounts (NEW - Critical!)

**⚠️ Important: Some accounts cannot be removed from AWS Organizations**

If you see accounts that cannot be removed (like `dev-app` #138412911194 and `dev-ml` #130361465823), **don't worry!** You have two options:

**Option A: Use Existing Accounts (Recommended for Beginners)**
```bash
# Check existing accounts in your organization
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email}' --output table

# Use these existing account IDs in your configuration
# Update your .env file with the existing account IDs
```

**Option B: Skip Account Creation**
```bash
# Modify the beginner's exercise to focus on:
# - IAM roles and policies
# - S3 and DynamoDB setup
# - GitHub Actions integration
# - Infrastructure deployment to existing accounts
```

#### Step 4: Create S3 Bucket for Terraform State (if needed)
```bash
# Create bucket for storing Terraform state (if not created by script)
aws s3 mb s3://terraform-state-$AWS_ACCOUNT_ID

# Enable versioning for state backup
aws s3api put-bucket-versioning --bucket terraform-state-$AWS_ACCOUNT_ID --versioning-configuration Status=Enabled

# Set up encryption
aws s3api put-bucket-encryption --bucket terraform-state-$AWS_ACCOUNT_ID --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
}'
```

#### Step 5: Create DynamoDB Table for State Locking (if needed)
```bash
# Create table for state locking (if not created by script)
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# Wait for table creation
aws dynamodb wait table-exists --table-name terraform-locks
```

#### Step 6: Configure Terraform Backend
```bash
# Navigate to global directory
cd global

# Create backend configuration
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "terraform-state-$MAIN_ACCOUNT_ID"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
EOF
```

#### Step 7: Deploy AWS Organization
```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="main_account_id=$AWS_ACCOUNT_ID" \
              -var="github_org=$GITHUB_ORG" \
              -var="github_repo=$GITHUB_REPO"

# Apply the configuration
terraform apply -var="main_account_id=$AWS_ACCOUNT_ID" \
               -var="github_org=$GITHUB_ORG" \
               -var="github_repo=$GITHUB_REPO"

# Confirm with "yes" when prompted
```

**Expected Output:**
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:
organization_id = "o-1234567890"
dev_shared_account_id = "123456789012"
staging_shared_account_id = "234567890123"
prod_shared_account_id = "345678901234"
github_actions_role_arn = "arn:aws:iam::082291634188:role/GitHubActionsOIDCRole"
```

#### Step 8: Handle Existing Resources (If Needed)

**⚠️ If you see errors about existing accounts or resources:**

If Terraform reports that accounts already exist or cannot be deleted, follow these steps:

1. **Check for existing accounts:**
```bash
# List existing accounts in your organization
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email}' --output table
```

2. **Use existing accounts (Recommended for beginners):**
   - If accounts already exist, you can use them instead of creating new ones
   - Update the beginner's exercise to reference the existing account IDs
   - Skip the account creation step and proceed to infrastructure deployment

3. **Focus on what you can deploy:**
   - IAM roles and policies
   - S3 and DynamoDB setup
   - GitHub Actions integration
   - Infrastructure deployment to existing accounts

#### Step 9: Update Environment Variables
```bash
# Update your .env file with the new account IDs
# Use the output from terraform apply to fill these in
```

**✅ Phase 3 Complete!** You now have a complete AWS Organization with 3 accounts.

---

### 🚀 **Phase 4: CI/CD Pipeline Setup** (45 minutes)

#### Step 1: Configure GitHub Repository Secrets
In your GitHub repository settings, add these secrets:
- `AWS_ROLE_ARN`: The GitHub Actions role ARN from Phase 3 output
- `AWS_REGION`: `us-east-1`

#### Step 2: Test CI/CD Pipeline
```bash
# Make a small change to trigger the pipeline
echo "# Test commit" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin main
```

#### Step 3: Monitor Pipeline Execution
1. Go to your GitHub repository
2. Click on "Actions" tab
3. Watch the Terraform CI workflow execute
4. Check that it successfully plans and applies changes

#### Step 4: Deploy Infrastructure to Each Environment
```bash
# Deploy to dev environment
cd environments/dev/shared
terraform init
terraform apply -var="account_id=$DEV_SHARED_ACCOUNT_ID"

# Deploy to staging environment
cd ../../environments/staging/shared
terraform init
terraform apply -var="account_id=$STAGING_SHARED_ACCOUNT_ID"

# Deploy to prod environment
cd ../../environments/prod/shared
terraform init
terraform apply -var="account_id=$PROD_SHARED_ACCOUNT_ID"
```

**✅ Phase 4 Complete!** Your CI/CD pipeline is working and infrastructure is deployed.

---

### 🧪 **Phase 5: Testing & Validation** (30 minutes)

#### Step 1: Test EKS Cluster Deployment
```bash
# Deploy sample application to dev cluster
cd environments/dev/shared
kubectl apply -f ../../examples/sample-app/

# Verify deployment
kubectl get pods -n sample-app
kubectl get services -n sample-app
```

#### Step 2: Test RDS Database
```bash
# Check RDS instance status
aws rds describe-db-instances --db-instance-identifier dev-shared-rds-db-primary

# Test database connectivity (if applicable)
```

#### Step 3: Test API Gateway
```bash
# Get API Gateway URL
aws apigateway get-rest-api --rest-api-id your-api-id

# Test the API endpoint
curl https://your-api-id.execute-api.us-east-1.amazonaws.com/dev
```

#### Step 4: Clean Up Resources
```bash
# Destroy dev environment (to save costs)
cd environments/dev/shared
terraform destroy -var="account_id=$DEV_SHARED_ACCOUNT_ID"

# Note: Keep staging and prod for continued learning
```

**✅ Phase 5 Complete!** You've successfully tested and validated your infrastructure.

---

## 🎉 **Exercise Complete!**

Congratulations! You've successfully completed the beginner's AWS multi-account infrastructure exercise. Here's what you've accomplished:

### 🏆 **Achievements Unlocked**
- ✅ Created and configured AWS Organizations
- ✅ Set up Terraform with proper state management
- ✅ Deployed infrastructure across multiple AWS accounts
- ✅ Configured GitHub Actions for CI/CD automation
- ✅ Deployed and tested Kubernetes applications
- ✅ Implemented professional cloud infrastructure practices

### 📊 **What You've Built**
```
AWS Organization (o-1234567890)
├── environments OU
│   ├── dev OU
│   │   └── dev-shared account (123456789012)
│   │       ├── EKS Cluster
│   │       ├── RDS Database
│   │       └── API Gateway
│   ├── staging OU
│   │   └── staging-shared account (234567890123)
│   │       ├── EKS Cluster
│   │       ├── RDS Database
│   │       └── API Gateway
│   └── prod OU
│       └── prod-shared account (345678901234)
│           ├── EKS Cluster
│           ├── RDS Database
│           └── API Gateway
└── Main Account (082291634188)
    ├── Terraform State S3 Bucket
    ├── DynamoDB Lock Table
    └── GitHub Actions OIDC Role
```

### 🔄 **Next Steps for Continued Learning**

1. **Advanced Kubernetes**: Learn Helm charts, ingress controllers, and service mesh
2. **Security Hardening**: Implement secrets management, network policies, and IAM fine-tuning
3. **Monitoring & Observability**: Set up CloudWatch, Prometheus, and Grafana
4. **Cost Optimization**: Implement resource tagging, budgets, and cost allocation
5. **Disaster Recovery**: Configure backup strategies and multi-region deployments

### 📚 **Additional Resources**

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://developer.hashicorp.com/terraform/tutorials)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### 🤝 **Need Help?**

If you encounter issues during the exercise:
1. Check the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) file
2. Review AWS CloudTrail logs for API errors
3. Check Terraform state and plan outputs
4. Consult the AWS documentation for service-specific guidance

**Common Issues & Solutions:**
- **Account limits**: Use existing accounts instead of creating new ones
- **Permission errors**: Ensure IAM user has AdministratorAccess policy
- **Terraform state conflicts**: Use `terraform force-unlock` if needed
- **Resource already exists**: Use `lifecycle { ignore_changes = [...] }` in Terraform
- **Existing resources**: Run `scripts/handle-existing-resources.sh` first
- **State conflicts**: Run `scripts/reset-terraform-state.sh` to reset state
- **Cannot remove accounts**: Use existing accounts or focus on deployable resources

---

## 📝 **Exercise Summary**

This beginner's exercise provided a complete foundation in:
- **AWS Multi-Account Architecture** using Organizations
- **Infrastructure as Code** with Terraform modules
- **CI/CD Automation** with GitHub Actions
- **Kubernetes Orchestration** with EKS
- **Database Management** with RDS
- **API Management** with API Gateway

You now have the skills to build and manage professional cloud infrastructure at scale. Keep practicing, and don't hesitate to explore more advanced topics as you become comfortable with these foundational concepts!

**Remember**: The key to mastering cloud infrastructure is continuous learning and hands-on practice. Use this foundation to build more complex systems and explore new AWS services!

## 🎯 **Special Feature: Working with Existing Accounts**

This exercise includes special guidance for working with existing AWS accounts:

- ✅ **Detect existing accounts** and use them instead of creating new ones
- ✅ **Focus on deployable resources** when accounts cannot be removed
- ✅ **Flexible approach** that works with any account setup
- ✅ **No manual cleanup required** - work with what you have
- ✅ **Complete learning experience** regardless of account situation