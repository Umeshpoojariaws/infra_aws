# Route 53 DNS Module
# Creates DNS records and hosted zones for the application

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account" {
  description = "Account type (app, ml, shared)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = null
}

variable "create_hosted_zone" {
  description = "Whether to create a new hosted zone"
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "Existing hosted zone ID (if not creating new)"
  type        = string
  default     = null
}

variable "records" {
  description = "List of DNS records to create"
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Create hosted zone if needed
resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = merge({
    Name        = "${var.env}-${var.account}-hosted-zone"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create DNS records
resource "aws_route53_record" "this" {
  count = length(var.records)

  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.hosted_zone_id
  name    = var.records[count.index].name
  type    = var.records[count.index].type
  ttl     = var.records[count.index].ttl
  records = var.records[count.index].records

  tags = merge({
    Name        = "${var.env}-${var.account}-dns-record-${count.index}"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create alias record for API Gateway (if provided)
resource "aws_route53_record" "api_gateway" {
  count = var.api_gateway_domain_name != null ? 1 : 0

  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.hosted_zone_id
  name    = var.api_gateway_domain_name
  type    = "A"

  alias {
    name                   = var.api_gateway_cloudfront_domain_name
    zone_id                = var.api_gateway_cloudfront_zone_id
    evaluate_target_health = false
  }

  tags = merge({
    Name        = "${var.env}-${var.account}-api-gateway-record"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create alias record for EKS (if provided)
resource "aws_route53_record" "eks" {
  count = var.eks_service_name != null ? 1 : 0

  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.hosted_zone_id
  name    = var.eks_service_name
  type    = "A"

  alias {
    name                   = var.eks_service_dns_name
    zone_id                = var.eks_service_zone_id
    evaluate_target_health = false
  }

  tags = merge({
    Name        = "${var.env}-${var.account}-eks-record"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Outputs
output "hosted_zone_id" {
  description = "The ID of the hosted zone"
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "The name servers of the hosted zone"
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}

output "record_names" {
  description = "The names of the created DNS records"
  value       = aws_route53_record.this[*].name
}

output "api_gateway_record_name" {
  description = "The name of the API Gateway DNS record"
  value       = var.api_gateway_domain_name != null ? var.api_gateway_domain_name : null
}

output "eks_record_name" {
  description = "The name of the EKS DNS record"
  value       = var.eks_service_name != null ? var.eks_service_name : null
}