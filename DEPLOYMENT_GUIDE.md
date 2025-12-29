# AWS Infrastructure Deployment Guide

This guide provides detailed instructions for deploying and managing the AWS infrastructure using Terraform and Terragrunt.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup](#setup)
3. [Deployment](#deployment)
4. [Management](#management)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)

## Prerequisites

### Required Tools

- **Terraform** >= 1.0
- **Terragrunt** >= 0.40
- **AWS CLI** >= 2.0
- **kubectl** >= 1.20
- **Docker** (optional, for local testing)

### AWS Account Setup

1. **Create AWS Organization** (if not already done):
   ```bash
   cd global
   terraform init
   terraform apply
   ```

2. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, region, and output format
   ```

3. **Set up IAM roles** for each environment account with appropriate permissions.

### Required AWS Services

- AWS Organizations
- EKS
- RDS
- API Gateway
- Route 53
- VPC
- IAM

## Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd infra_aws/git
```

### 2. Configure Environment Variables

Create a `.env` file with your configuration:

```bash
# AWS Configuration
export AWS_REGION="us-east-1"
export AWS_PROFILE="your-profile"

# Terraform Configuration
export TF_VAR_environment="dev"
export TF_VAR_account="shared"

# Application Configuration
export APP_NAME="your-app"
export DOMAIN_NAME="yourdomain.com"
```

### 3. Initialize Backend Storage

Create S3 buckets for Terraform state:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://terraform-state-bucket --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

## Deployment

### 1. Deploy Global Resources (One-time Setup)

```bash
cd global
terraform init
terraform apply
```

This creates:
- AWS Organization structure
- Organizational Units (dev, staging, prod)
- Accounts for each environment
- Service Control Policies

### 2. Deploy Environment Resources

#### Option A: Using Terragrunt (Recommended)

```bash
# Deploy shared services first
cd environments/dev/shared
terragrunt init
terragrunt apply

# Deploy app services
cd ../app
terragrunt init
terragrunt apply

# Deploy ML services
cd ../ml
terragrunt init
terragrunt apply
```

#### Option B: Using Terraform Directly

```bash
# Deploy shared services
cd environments/dev/shared
terraform init
terraform apply

# Deploy app services
cd ../../dev/app
terraform init
terraform apply

# Deploy ML services
cd ../ml
terraform init
terraform apply
```

### 3. Deploy Kubernetes Resources

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name dev-shared-eks-cluster-main

# Deploy applications
kubectl apply -f environments/dev/shared/k8s-manifests/
```

### 4. Deploy Multiple Environments

```bash
# Staging environment
cd environments/staging/shared
terragrunt apply

# Production environment
cd ../../prod/shared
terragrunt apply
```

## Management

### Viewing Resources

```bash
# List all resources in an environment
terragrunt state list

# Show specific resource
terragrunt state show aws_eks_cluster.this

# View outputs
terragrunt output
```

### Updating Resources

```bash
# Make changes to configuration files
# Then apply changes
terragrunt plan
terragrunt apply
```

### Adding New Services

1. **Create new module** in `modules/` directory
2. **Update environment configuration** to include the new module
3. **Apply changes** using Terragrunt

### Scaling Resources

```bash
# Scale EKS node groups
terragrunt plan -var='node_groups={main={desired_size=4}}'
terragrunt apply
```

### Managing Secrets

```bash
# View Kubernetes secrets
kubectl get secrets

# Update secrets
kubectl edit secret dev-shared-eks-cluster-main-db-secret
```

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock

**Problem**: Terraform state is locked by another process.

**Solution**:
```bash
# Check if lock exists
aws dynamodb get-item --table-name terraform-locks --key '{"LockID":{"S":"path/to/state"}}'

# Force unlock (use with caution)
terragrunt force-unlock LOCK_ID
```

#### 2. AWS Permissions

**Problem**: Insufficient IAM permissions.

**Solution**:
- Check IAM policies attached to your user/role
- Ensure you have permissions for all required services
- Verify you can assume the correct roles in each account

#### 3. VPC Peering Issues

**Problem**: VPC peering connection fails.

**Solution**:
- Check that VPC CIDR blocks don't overlap
- Verify route tables are correctly configured
- Ensure security groups allow necessary traffic

#### 4. EKS Cluster Issues

**Problem**: EKS cluster creation fails.

**Solution**:
- Check IAM roles have required permissions
- Verify subnets are correctly configured
- Check security groups allow necessary traffic

#### 5. RDS Connection Issues

**Problem**: Cannot connect to RDS from EKS.

**Solution**:
- Verify security groups allow traffic between EKS and RDS
- Check that RDS is in the correct subnets
- Ensure Kubernetes secrets are correctly configured

### Debug Commands

```bash
# Check Terraform logs
export TF_LOG=DEBUG
terragrunt plan

# Check AWS API calls
aws configure set cli_history enabled

# Check Kubernetes events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check pod logs
kubectl logs <pod-name> -n <namespace>
```

### Recovery Procedures

#### 1. Restore from Backup

```bash
# Download state from S3
aws s3 cp s3://terraform-backups/dev/shared/backup.tfstate terraform.tfstate

# Import state
terraform import aws_eks_cluster.this <cluster-name>
```

#### 2. Rebuild Environment

```bash
# Destroy and recreate
terragrunt destroy
terragrunt apply
```

## Best Practices

### 1. Version Control

- Use Git for all infrastructure code
- Implement pull request reviews
- Tag releases
- Use semantic versioning

### 2. Security

- Use IAM roles instead of access keys
- Enable MFA for all users
- Regularly rotate credentials
- Use secrets management (AWS Secrets Manager)
- Enable encryption at rest and in transit

### 3. Monitoring

- Enable CloudTrail for API logging
- Set up CloudWatch alarms
- Monitor cost and usage
- Use Prometheus/Grafana for Kubernetes monitoring

### 4. Cost Optimization

- Use appropriate instance types
- Enable auto-scaling
- Use spot instances for non-critical workloads
- Clean up unused resources
- Implement resource tagging for cost allocation

### 5. Testing

- Test changes in development environment first
- Use `terraform plan` before applying
- Implement automated testing
- Use canary deployments for production

### 6. Documentation

- Document all changes
- Maintain runbooks for common procedures
- Keep architecture diagrams up to date
- Document troubleshooting procedures

### 7. Backup and Recovery

- Regularly backup Terraform state
- Test recovery procedures
- Keep multiple backup copies
- Document recovery steps

## Support

For additional support:

1. Check the [troubleshooting](#troubleshooting) section
2. Review Terraform and Terragrunt documentation
3. Check AWS documentation for service-specific issues
4. Contact the infrastructure team

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for your changes
5. Submit a pull request

## License

This project is licensed under the MIT License.