# Root Terragrunt configuration
# This file provides common configuration for all environments

# Prevent double initialization
prevent_destroy = false

# Terraform configuration
terraform {
  # Extra arguments for all terraform commands
  extra_arguments "bucket" {
    commands = [
      "init"
    ]

    arguments = [
      "-backend-config=encrypt=true",
      "-backend-config=dynamodb_table=terraform-locks"
    ]
  }

  # Before hook to check if AWS credentials are configured
  before_hook "validate_aws_credentials" {
    commands     = ["apply", "plan", "destroy"]
    execute      = ["aws", "sts", "get-caller-identity"]
    run_on_error = false
  }
}

# Remote state configuration
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-${get_aws_account_id()}"
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

# Inputs that are common across all environments
inputs = {
  # AWS configuration
  aws_region = "us-east-1"

  # Common tags
  common_tags = {
    ManagedBy   = "terraform"
    Environment = "dev"
    Account     = "shared"
  }

  # Security configuration
  enable_encryption = true
  kms_key_id        = "alias/aws/s3"

  # Monitoring configuration
  enable_monitoring = true
  cloudwatch_logs   = true
  cloudwatch_metrics = true

  # Backup configuration
  backup_enabled = true
  backup_retention_days = 30

  # Network configuration
  enable_vpc_peering = true
  enable_transit_gateway = false
}