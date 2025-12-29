# Terraform Backend Configuration
# This file configures the backend for storing Terraform state

terraform {
  backend "s3" {
    bucket         = "terraform-state-1767001086-082291634188"  # Replace with your bucket name
    key            = "organization.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
    acl            = "bucket-owner-full-control"
  }
}

# Instructions:
# 1. Run the setup script to create the S3 bucket
# 2. Replace "terraform-state-CHANGE_ME" with your actual bucket name
# 3. The bucket name must be globally unique
# 4. Example: "terraform-state-1767001086-082291634188"