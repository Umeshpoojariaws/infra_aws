# 🚀 AWS Multi-Account Setup - Complete Beginner's Exercise

This guide will walk you through setting up a complete AWS multi-account infrastructure from scratch. Perfect for beginners who want to learn AWS Organizations, Terraform, and CI/CD!

## 📋 **Prerequisites Checklist**

Before starting, make sure you have:

- [ ] **Computer** with internet access
- [ ] **Email address** for AWS account creation
- [ ] **Credit card** (AWS requires payment method for account creation)
- [ ] **Time** (This exercise takes 2-3 hours for beginners)

## 🎯 **What You'll Build**

By the end of this exercise, you'll have:
- ✅ **AWS Organization** with 3 accounts (dev, staging, prod)
- ✅ **Terraform setup** for infrastructure as code
- ✅ **GitHub Actions CI/CD** pipeline
- ✅ **EKS clusters** in each environment
- ✅ **RDS databases** with automated secrets
- ✅ **Complete documentation** and automation scripts

## 📚 **Exercise Overview**

### **Phase 1: AWS Account Setup** (30 minutes)
### **Phase 2: Development Environment** (45 minutes)  
### **Phase 3: Infrastructure as Code** (60 minutes)
### **Phase 4: CI/CD Pipeline** (45 minutes)
### **Phase 5: Testing & Validation** (30 minutes)

---

# 📁 **Phase 1: AWS Account Setup**

## Step 1: Create Your AWS Account

### 1.1 Sign Up for AWS
1. Go to [https://aws.amazon.com/](https://aws.amazon.com/)
2. Click **"Create an AWS Account"**
3. Enter your email address and click **"Continue"**
4. Create a password and click **"Sign in using our sign-in assistance"**

### 1.2 Account Information
Fill in your personal/business information:
- **Account name**: `MyCloudTraining`
- **Root user email**: `your-email@example.com`
- **Password**: Create a strong password
- **Country/Region**: Select your country

### 1.3 Payment Information
AWS requires a payment method (you won't be charged during the free tier):
- **Name on card**: Your name
- **Card number**: Your credit/debit card
- **Expiration date**: Card expiration
- **CVV**: Card security code
- **Billing address**: Your address

### 1.4 Identity Verification
AWS will verify your identity (usually via phone call):
- **Phone number**: Enter your phone number
- **Verification**: AWS will call you with a PIN
- **Enter PIN**: Provide the PIN when prompted

### 1.5 Support Plan Selection
Choose **"Basic (Free)"** support plan

**✅ AWS Account Created!**

## Step 2: Get Your Account Information

### 2.1 Find Your Account ID
1. Sign in to AWS Console: [https://console.aws.amazon.com/](https://console.aws.amazon.com/)
2. Click on your account name in the top-right
3. Click **"My Account"**
4. Copy your **Account ID** (12-digit number)
5. Save it: `MAIN_ACCOUNT_ID=123456789012`

### 2.2 Set Up AWS CLI Access
1. Go to IAM Console: [https://console.aws.amazon.com/iam/](https://console.aws.amazon.com/iam/)
2. Click **"Users"** in the left menu
3. Click **"Add user"**
4. **User name**: `terraform-admin`
5. **Access type**: Check **"Programmatic access"**
6. Click **"Next: Permissions"**
7. Click **"Attach existing policies directly"**
8. Search for and select **"AdministratorAccess"**
9. Click **"Next: Tags"**
10. Add tag: `Key=ManagedBy, Value=terraform`
11. Click **"Next: Review"**
12. Click **"Create user"**

### 2.3 Save Access Keys
After user creation, you'll see:
- **Access key ID**: `AKIAIOSFODNN7EXAMPLE`
- **Secret access key**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

**⚠️ Save these keys immediately! You can't see them again.**

## Step 3: Install Required Tools

### 3.1 Install AWS CLI
**Windows:**
```bash
# Download and run installer
https://awscli.amazonaws.com/AWSCLIV2.msi
```

**Mac (with Homebrew):**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 3.2 Configure AWS CLI
```bash
aws configure
# Enter when prompted:
# AWS Access Key ID: [your-access-key-id]
# AWS Secret Access Key: [your-secret-access-key]
# Default region name: us-east-1
# Default output format: json
```

### 3.3 Install Terraform
**Windows:**
```bash
# Download from: https://www.terraform.io/downloads
# Extract and add to PATH
```

**Mac (with Homebrew):**
```bash
brew install terraform
```

**Linux:**
```bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 3.4 Install Git
**Windows/Mac:** Download from [https://git-scm.com/](https://git-scm.com/)
**Linux:**
```bash
sudo apt-get install git  # Ubuntu/Debian
sudo yum install git      # CentOS/RHEL
```

### 3.5 Install jq (JSON processor)
**Mac:**
```bash
brew install jq
```

**Linux:**
```bash
sudo apt-get install jq  # Ubuntu/Debian
sudo yum install jq      # CentOS/RHEL
```

## Step 4: Verify Setup

```bash
# Test AWS CLI
aws sts get-caller-identity

# Expected output:
# {
#   "UserId": "AIDAEXAMPLEID",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/terraform-admin"
# }

# Test Terraform
terraform --version
# Expected: Terraform v1.6.0

# Test Git
git --version
# Expected: git version 2.x.x
```

**✅ Phase 1 Complete! You have a working AWS account and tools.**

---

# 🛠️ **Phase 2: Development Environment**

## Step 5: Set Up Your Development Environment

### 5.1 Create Project Directory
```bash
# Create project folder
mkdir ~/aws-multi-account-training
cd ~/aws-multi-account-training

# Clone the infrastructure code
git clone https://github.com/your-username/aws-multi-account-infra.git
cd aws-multi-account-infra
```

### 5.2 Set Environment Variables
Create a `.env` file with your configuration:
```bash
cat > .env << 'EOF'
# AWS Configuration
export MAIN_ACCOUNT_ID=123456789012
export AWS_REGION=us-east-1

# GitHub Configuration (for later)
export GITHUB_ORG=my-training-org
export GITHUB_REPO=aws-multi-account-infra

# Environment Configuration
export ENVIRONMENTS="dev,staging,prod"
EOF

# Load environment variables
source .env
```

### 5.3 Create GitHub Repository
1. Go to [https://github.com/new](https://github.com/new)
2. **Repository name**: `aws-multi-account-infra`
3. **Description**: `AWS Multi-Account Infrastructure with Terraform`
4. **Public**: ✓ (recommended for learning)
5. **Initialize this repository with a README**: ✓
6. Click **"Create repository"**

### 5.4 Push Code to GitHub
```bash
# Initialize git
git init
git add .
git commit -m "Initial commit: AWS multi-account infrastructure"

# Add GitHub remote
git remote add origin https://github.com/your-username/aws-multi-account-infra.git

# Push to GitHub
git branch -M main
git push -u origin main
```

**✅ Phase 2 Complete! Your development environment is ready.**

---

# 🏗️ **Phase 3: Infrastructure as Code**

## Step 6: Set Up Terraform Backend

### 6.1 Create S3 Bucket for State
```bash
# Create bucket name (must be globally unique)
BUCKET_NAME="terraform-state-$(date +%s)-${MAIN_ACCOUNT_ID}"

# Create the bucket
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "Terraform state bucket: $BUCKET_NAME"
```

### 6.2 Create DynamoDB Table for Locking
```bash
# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region $AWS_REGION

echo "DynamoDB table created: terraform-locks"
```

### 6.3 Configure Terraform Backend
Edit `global/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-1234567890-123456789012"  # Replace with your bucket name
    key            = "organization.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Step 7: Create AWS Organization

### 7.1 Initialize Terraform
```bash
cd global
terraform init
```

### 7.2 Review the Plan
```bash
terraform plan -var="main_account_id=$MAIN_ACCOUNT_ID" \
              -var="github_org=$GITHUB_ORG" \
              -var="github_repo=$GITHUB_REPO"
```

### 7.3 Apply the Configuration
```bash
terraform apply -var="main_account_id=$MAIN_ACCOUNT_ID" \
               -var="github_org=$GITHUB_ORG" \
               -var="github_repo=$GITHUB_REPO"
```

**Type `yes` when prompted to confirm.**

This will create:
- ✅ AWS Organization
- ✅ Organizational Units (dev, staging, prod)
- ✅ Accounts (dev-shared, staging-shared, prod-shared)
- ✅ Terraform role with OIDC authentication
- ✅ S3 bucket and DynamoDB table

### 7.4 Verify Organization Creation
```bash
# List accounts in your organization
aws organizations list-accounts

# Expected output should show 4 accounts:
# - Management account (your main account)
# - dev-shared account
# - staging-shared account  
# - prod-shared account
```

**✅ Phase 3 Complete! Your AWS Organization is ready.**

---

# 🚀 **Phase 4: CI/CD Pipeline**

## Step 8: Set Up GitHub Actions

### 8.1 Create GitHub Secrets
1. Go to your GitHub repository
2. Click **"Settings"** → **"Secrets and variables"** → **"Actions"**
3. Click **"New repository secret"**

Add these secrets:
- **Name**: `AWS_ROLE_ARN`
- **Value**: `arn:aws:iam::123456789012:role/TerraformRole` (from Terraform output)

### 8.2 Test the CI/CD Pipeline
1. Create a new branch:
```bash
git checkout -b test-cicd
```

2. Make a small change (add a comment to any file)

3. Commit and push:
```bash
git add .
git commit -m "Test CI/CD pipeline"
git push origin test-cicd
```

4. Create a Pull Request on GitHub

5. Check the **Actions** tab to see the pipeline run

### 8.3 Set Up GitHub CLI (Optional)
```bash
# Install GitHub CLI
# Mac: brew install gh
# Windows: winget install GitHub.cli
# Linux: See https://cli.github.com/

# Authenticate
gh auth login

# Set up secrets using CLI
gh secret set AWS_ROLE_ARN -b"arn:aws:iam::123456789012:role/TerraformRole"
```

## Step 9: Deploy Environment Infrastructure

### 9.1 Deploy Dev Environment
```bash
cd environments/dev/shared

# Initialize
terraform init -backend-config="bucket=terraform-state-1234567890-123456789012"

# Plan
terraform plan

# Apply
terraform apply
```

This will create:
- ✅ VPC with subnets
- ✅ EKS cluster
- ✅ RDS database
- ✅ API Gateway
- ✅ Route 53 records

### 9.2 Deploy Staging Environment
```bash
cd ../../staging/shared
terraform init -backend-config="bucket=terraform-state-1234567890-123456789012"
terraform apply
```

### 9.3 Deploy Production Environment
```bash
cd ../../prod/shared
terraform init -backend-config="bucket=terraform-state-1234567890-123456789012"
terraform apply
```

**⚠️ Note: Production deployment will take 15-20 minutes for EKS cluster creation.**

**✅ Phase 4 Complete! Your CI/CD pipeline is working.**

---

# 🧪 **Phase 5: Testing & Validation**

## Step 10: Test Your Infrastructure

### 10.1 Verify EKS Clusters
```bash
# Get EKS cluster credentials
aws eks update-kubeconfig --region us-east-1 --name dev-shared-eks-cluster-main

# Test cluster access
kubectl get nodes
kubectl get pods --all-namespaces

# Expected: You should see worker nodes and system pods running
```

### 10.2 Test RDS Database
```bash
# Get database endpoint from Terraform output
terraform output -raw rds_endpoint

# Test database connectivity (you'll need to install MySQL client)
mysql -h [endpoint] -u admin -p
# Enter the password from Terraform output
```

### 10.3 Test API Gateway
```bash
# Get API endpoint from Terraform output
terraform output -raw api_gateway_url

# Test the API
curl https://[api-id].execute-api.us-east-1.amazonaws.com/v1/
```

### 10.4 Test Cross-Account Access
```bash
# Switch to dev account
aws sts assume-role --role-arn arn:aws:iam::[dev-account-id]:role/TerraformRole --role-session-name test

# Verify you can access dev account resources
aws sts get-caller-identity
```

## Step 11: Create Your First Application

### 11.1 Deploy Sample Application
```bash
# Deploy frontend
kubectl apply -f environments/dev/shared/k8s-manifests/frontend-deployment.yaml

# Deploy backend
kubectl apply -f environments/dev/shared/k8s-manifests/backend-deployment.yaml

# Verify deployment
kubectl get pods
kubectl get services
```

### 11.2 Test Application
```bash
# Get service IP
kubectl get services

# Access the application
curl http://[service-ip]:3000
```

## Step 12: Clean Up (Important!)

### 12.1 Destroy Test Resources
```bash
# Destroy dev environment
cd environments/dev/shared
terraform destroy

# Destroy staging environment
cd ../../staging/shared
terraform destroy

# Destroy production environment
cd ../../prod/shared
terraform destroy
```

### 12.2 Destroy Organization (Optional)
```bash
# Only if you want to completely clean up
cd global
terraform destroy
```

### 12.3 Delete S3 Bucket and DynamoDB
```bash
# Delete S3 bucket contents
aws s3 rm s3://your-bucket-name --recursive

# Delete bucket
aws s3 rb s3://your-bucket-name --force

# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-locks
```

**✅ Phase 5 Complete! You've successfully tested everything.**

---

# 📚 **Exercise Completion Checklist**

## ✅ **You've Learned:**

- [ ] How to create and configure an AWS account
- [ ] AWS Organizations and multi-account structure
- [ ] Terraform for infrastructure as code
- [ ] S3 and DynamoDB for state management
- [ ] EKS cluster creation and management
- [ ] RDS database setup with automated secrets
- [ ] API Gateway and Route 53 configuration
- [ ] GitHub Actions for CI/CD automation
- [ ] Cross-account IAM roles and permissions
- [ ] Kubernetes application deployment

## 🎯 **Next Steps to Continue Learning:**

1. **Add More Services**: Try adding Redis, ElastiCache, or S3 buckets
2. **Implement Monitoring**: Add CloudWatch dashboards and alarms
3. **Security Hardening**: Implement additional security controls
4. **Cost Optimization**: Set up budgets and cost monitoring
5. **Advanced CI/CD**: Add automated testing and deployment strategies

## 🆘 **Troubleshooting Common Issues:**

### **AWS CLI Authentication Errors**
```bash
# Reconfigure AWS CLI
aws configure
# Or check credentials
aws sts get-caller-identity
```

### **Terraform State Lock Errors**
```bash
# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

### **EKS Cluster Creation Failures**
- Check IAM permissions
- Verify VPC and subnet configuration
- Ensure sufficient AWS service limits

### **GitHub Actions Failures**
- Check GitHub secrets are set correctly
- Verify OIDC provider configuration
- Check Terraform plan output for errors

## 📞 **Getting Help:**

- **AWS Documentation**: [https://docs.aws.amazon.com/](https://docs.aws.amazon.com/)
- **Terraform Documentation**: [https://www.terraform.io/docs/](https://www.terraform.io/docs/)
- **GitHub Actions Documentation**: [https://docs.github.com/en/actions](https://docs.github.com/en/actions)
- **AWS Support**: Use AWS Support Center for account issues

---

# 🎉 **Congratulations!**

You've successfully completed the AWS Multi-Account Infrastructure exercise! 

**What you've accomplished:**
- ✅ Built a production-ready multi-account AWS environment
- ✅ Implemented infrastructure as code with Terraform
- ✅ Set up automated CI/CD with GitHub Actions
- ✅ Deployed containerized applications on Kubernetes
- ✅ Learned AWS best practices for security and organization

**Save this repository and documentation** - it's a great foundation for future projects and a valuable addition to your portfolio!

**Share your success**: Tweet about your accomplishment with #AWS #Terraform #DevOps

---

## 📝 **Exercise Feedback**

How was your experience with this exercise?

- [ ] **Easy to follow** - All steps were clear
- [ ] **Challenging but doable** - Learned a lot
- [ ] **Too difficult** - Need more guidance
- [ ] **Too easy** - Want more advanced content

**Suggestions for improvement:**
_________________________________
_________________________________
_________________________________

**What would you like to learn next?**
_________________________________
_________________________________
_________________________________

Thank you for completing this exercise! Happy cloud computing! 🚀