# Dev App Account Configuration
# This file configures application services for the dev environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "dev-app-tfstate"
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
  account     = "app"
  vpc_cidr    = "10.1.0.0/16"
}

# Create VPC with peering to shared account
module "vpc" {
  source = "../../modules/vpc-peering"

  env        = local.env
  account    = local.account
  vpc_cidr   = local.vpc_cidr
  region     = "us-east-1"
  peer_vpc_cidrs = [
    "10.0.0.0/16"  # dev-shared VPC
  ]
  peer_account_ids = [
    "123456789011"  # dev-shared account ID
  ]
}

# Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}