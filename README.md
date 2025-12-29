# AWS Infrastructure Terraform Repository

This repository contains the Terraform code for managing AWS infrastructure using a multi-account strategy with Kubernetes (EKS) as the core orchestration platform.

## Architecture Overview

The infrastructure design leverages:
- **AWS Organizations** for multi-account governance
- **Terraform** for declarative Infrastructure as Code (IaC)
- **Kubernetes (EKS)** as the core orchestration platform
- **Modular, reusable components** for scalability

## Project Structure

```
terraform-root/
├── environments/
│   ├── dev/
│   │   ├── app/          # dev-app account
│   │   │   ├── main.tf   # Calls modules for frontend/backend
│   │   │   └── terragrunt.hcl
│   │   ├── ml/           # dev-ml account
│   │   │   ├── main.tf   # ML/AI services
│   │   │   └── terragrunt.hcl
│   │   └── shared/       # dev-shared account
│   │       ├── main.tf   # EKS, DB, API GW, DNS
│   │       └── terragrunt.hcl
│   ├── staging/          # Similar structure
│   └── prod/             # Similar structure
├── modules/
│   ├── eks-cluster/      # Reusable EKS module
│   ├── rds-db/           # RDS with auto-secrets
│   ├── api-gateway/      # API GW integration
│   ├── route53-dns/      # DNS records
│   └── vpc-peering/      # Cross-account networking
└── global/               # AWS Org setup (run once)
    └── organization.tf   # Organizations root
```

## Naming Conventions

- Format: `{env}-{account}-{service}-{resource}-{suffix}`
- Examples:
  - `dev-app-eks-cluster-main`
  - `dev-shared-rds-db-prod`
  - `staging-ml-eks-cluster-dev2`

## Environments & Accounts

| Environment | Accounts | Services Hosted | Communication |
|-------------|----------|-----------------|---------------|
| Dev        | dev-app | Frontend (3 services), Backend (1) | VPC Peering to dev-shared |
| Dev        | dev-ml  | ML/AI (2 services) | Transit Gateway to dev-app |
| Dev        | dev-shared | DB, API Gateway, DNS, EKS clusters | Centralized hub |
| Staging    | staging-app, staging-ml, staging-shared | Similar partition | Isolated peering |
| Prod       | prod-app, prod-ml, prod-shared | Scaled versions | High-availability peering |

## Getting Started

1. **Prerequisites**:
   - Terraform >= 1.0
   - AWS CLI configured
   - Terragrunt (optional, for orchestration)

2. **Setup AWS Organization** (run once):
   ```bash
   cd global
   terraform init
   terraform apply
   ```

3. **Deploy Environment**:
   ```bash
   cd environments/dev/shared
   terraform init
   terraform apply
   ```

## Usage

### Creating New Clusters

**Option 1: New Cluster in New Account**
- Add new account in `global/organization.tf`
- Create new environment directory structure
- Configure `terragrunt.hcl` for orchestration

**Option 2: Namespace in Existing Cluster**
- Update `eks-cluster` module with new cluster configuration
- Use Kubernetes provider to create namespaces
- Deploy services to new namespaces

### Adding New Services

1. Update the appropriate environment's `main.tf`
2. Add service-specific configurations
3. Apply changes:
   ```bash
   terraform apply
   ```

## Security

- All resources are tagged with `env` and `account`
- Cross-account roles via IAM
- EKS private clusters
- RDS encryption
- Secrets managed via Kubernetes secrets

## Monitoring & Observability

- CloudWatch integration for AWS resources
- Prometheus for EKS monitoring
- Centralized logging

## Contributing

1. Create feature branch from `main`
2. Make changes following the existing structure
3. Test with `terraform plan`
4. Submit pull request

## License

This project is licensed under the MIT License.