# VPC Peering Module Variables

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account" {
  description = "Account type (app, ml, shared)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "peer_vpc_cidrs" {
  description = "List of peer VPC CIDR blocks"
  type        = list(string)
  default     = []
}

variable "peer_account_ids" {
  description = "List of peer account IDs"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}