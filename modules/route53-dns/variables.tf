# Route 53 DNS Module Variables

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

variable "api_gateway_domain_name" {
  description = "API Gateway custom domain name"
  type        = string
  default     = null
}

variable "api_gateway_cloudfront_domain_name" {
  description = "API Gateway CloudFront domain name"
  type        = string
  default     = null
}

variable "api_gateway_cloudfront_zone_id" {
  description = "API Gateway CloudFront zone ID"
  type        = string
  default     = null
}

variable "eks_service_name" {
  description = "EKS service name for DNS record"
  type        = string
  default     = null
}

variable "eks_service_dns_name" {
  description = "EKS service DNS name"
  type        = string
  default     = null
}

variable "eks_service_zone_id" {
  description = "EKS service zone ID"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}