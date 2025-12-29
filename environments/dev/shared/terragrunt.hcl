# Terragrunt configuration for dev shared environment
# This file orchestrates the deployment of shared services

# Include the root terragrunt.hcl configuration
include {
  path = find_in_parent_folders()
}

# Terragrunt inputs
inputs = {
  # Environment configuration
  environment = "dev"
  account     = "shared"

  # VPC configuration
  vpc_cidr = "10.0.0.0/16"

  # EKS cluster configuration
  cluster_name = "dev-shared-eks-cluster-main"
  kubernetes_version = "1.28"

  # Node groups configuration
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

  # RDS configuration
  rds_instance_class = "db.t3.micro"
  rds_allocated_storage = 20
  rds_multi_az = false
  rds_database_name = "appdb"
  rds_username = "admin"

  # API Gateway configuration
  api_gateway_name = "dev-shared-api-gateway"
  create_api_key = true

  # DNS configuration
  domain_name = "app.yourorg.com"
  dns_records = [
    {
      name    = "eks.dev"
      type    = "A"
      ttl     = 300
      records = []
    },
    {
      name    = "api.dev"
      type    = "A"
      ttl     = 300
      records = []
    }
  ]

  # Clusters configuration (for multiple clusters)
  clusters = [
    {
      name = "main"
      services = ["frontend", "backend"]
    },
    {
      name = "dev2"
      services = ["ml", "ai"]
    }
  ]

  # Tags
  common_tags = {
    Environment = "dev"
    Account     = "shared"
    ManagedBy   = "terraform"
  }
}

# Remote state configuration
remote_state {
  backend = "s3"
  config = {
    bucket         = "dev-shared-tfstate"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
    acl            = "bucket-owner-full-control"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Dependencies
dependencies {
  paths = [
    "../app",
    "../ml"
  ]
}

# Dependency outputs
dependency "app_vpc" {
  config_path = "../app"
  mock_outputs = {
    vpc_id = "vpc-1234567890abcdef0"
    private_subnet_ids = ["subnet-1234567890abcdef0", "subnet-1234567890abcdef1"]
  }
}

dependency "ml_vpc" {
  config_path = "../ml"
  mock_outputs = {
    vpc_id = "vpc-1234567890abcdef1"
    private_subnet_ids = ["subnet-1234567890abcdef2", "subnet-1234567890abcdef3"]
  }
}

# Generate backend configuration
generate "backend" {
  path = "backend.tf"
  if_exists = "skip"
  contents = <<EOF
terraform {
  backend "s3" {
    bucket         = "dev-shared-tfstate"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
EOF
}

# Generate provider configuration
generate "provider" {
  path = "provider.tf"
  if_exists = "skip"
  contents = <<EOF
provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = base64decode(var.kubernetes_ca_certificate)
  token                  = var.kubernetes_token
}
EOF
}