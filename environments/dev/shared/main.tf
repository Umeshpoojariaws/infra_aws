# Dev Shared Account Configuration
# This file configures shared services for the dev environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }

  backend "s3" {
    bucket         = "dev-shared-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# Local variables for naming conventions
locals {
  env         = "dev"
  account     = "shared"
  cluster_name = "${local.env}-${local.account}-eks-cluster-main"
  vpc_cidr    = "10.0.0.0/16"
}

# Create VPC with peering
module "vpc" {
  source = "../../modules/vpc-peering"

  env        = local.env
  account    = local.account
  vpc_cidr   = local.vpc_cidr
  region     = "us-east-1"
  peer_vpc_cidrs = [
    "10.1.0.0/16",  # dev-app VPC
    "10.2.0.0/16"   # dev-ml VPC
  ]
  peer_account_ids = [
    "123456789012",  # dev-app account ID
    "123456789013"   # dev-ml account ID
  ]
}

# Create EKS cluster
module "eks" {
  source = "../../modules/eks-cluster"

  env          = local.env
  account      = local.account
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  node_groups = {
    main = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      max_size       = 4
      min_size       = 1
      disk_size      = 20
      labels         = {}
      tags           = {}
    }
    gpu = {
      instance_types = ["g4dn.xlarge"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 1
      max_size       = 2
      min_size       = 0
      disk_size      = 50
      labels         = { node-type = "gpu" }
      tags           = {}
    }
  }

  tags = {
    Environment = local.env
    Account     = local.account
  }
}

# Create RDS database
module "rds" {
  source = "../../modules/rds-db"

  env          = local.env
  account      = local.account
  db_name      = "${local.env}-${local.account}-rds-db-primary"
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  database_name = "appdb"
  username      = "admin"
  multi_az      = false

  namespace = "default"

  kubernetes_host                   = module.eks.cluster_endpoint
  kubernetes_ca_certificate         = module.eks.kubeconfig_certificate_authority_data
  kubernetes_token                  = data.aws_eks_cluster_auth.this.token

  tags = {
    Environment = local.env
    Account     = local.account
  }
}

# Create API Gateway
module "api_gateway" {
  source = "../../modules/api-gateway"

  env               = local.env
  account           = local.account
  api_name          = "${local.env}-${local.account}-api-gateway"
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.vpc_security_group_id]

  vpc_endpoint_id         = "vpce-1234567890abcdef0"  # Replace with actual VPC endpoint ID
  eks_service_endpoint    = module.eks.cluster_endpoint
  create_api_key          = true
  api_key_value           = "dev-api-key-12345"

  tags = {
    Environment = local.env
    Account     = local.account
  }
}

# Create DNS records
module "dns" {
  source = "../../modules/route53-dns"

  env         = local.env
  account     = local.account
  domain_name = "app.yourorg.com"

  records = [
    {
      name    = "eks.${local.env}"
      type    = "A"
      ttl     = 300
      records = [module.eks.cluster_endpoint]
    },
    {
      name    = "api.${local.env}"
      type    = "A"
      ttl     = 300
      records = [module.api_gateway.invoke_url]
    }
  ]

  tags = {
    Environment = local.env
    Account     = local.account
  }
}

# Data source for EKS cluster authentication
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

# Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = module.rds.db_endpoint
}

output "api_gateway_url" {
  description = "The URL of the API Gateway"
  value       = module.api_gateway.invoke_url
}

output "dns_zone_id" {
  description = "The ID of the DNS zone"
  value       = module.dns.hosted_zone_id
}