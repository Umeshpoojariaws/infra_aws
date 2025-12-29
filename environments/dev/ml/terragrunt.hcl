# Terragrunt configuration for dev ml environment
# This file orchestrates the deployment of ML/AI services

# Include the root terragrunt.hcl configuration
include {
  path = find_in_parent_folders()
}

# Terragrunt inputs
inputs = {
  # Environment configuration
  environment = "dev"
  account     = "ml"

  # VPC configuration
  vpc_cidr = "10.2.0.0/16"

  # Tags
  common_tags = {
    Environment = "dev"
    Account     = "ml"
    ManagedBy   = "terraform"
  }
}

# Remote state configuration
remote_state {
  backend = "s3"
  config = {
    bucket         = "dev-ml-tfstate"
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
    "../shared"
  ]
}

# Dependency outputs
dependency "shared_vpc" {
  config_path = "../shared"
  mock_outputs = {
    vpc_id = "vpc-1234567890abcdef0"
    private_subnet_ids = ["subnet-1234567890abcdef0", "subnet-1234567890abcdef1"]
  }
}

# Generate backend configuration
generate "backend" {
  path = "backend.tf"
  if_exists = "skip"
  contents = <<EOF
terraform {
  backend "s3" {
    bucket         = "dev-ml-tfstate"
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
EOF
}