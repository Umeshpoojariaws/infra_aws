# API Gateway Module Variables

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account" {
  description = "Account type (app, ml, shared)"
  type        = string
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
}

variable "description" {
  description = "API Gateway description"
  type        = string
  default     = "API Gateway for EKS services"
}

variable "stage_name" {
  description = "Stage name for the API"
  type        = string
  default     = "v1"
}

variable "vpc_id" {
  description = "VPC ID for the API Gateway"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the API Gateway"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the API Gateway"
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_id" {
  description = "VPC endpoint ID for API Gateway access"
  type        = string
}

variable "eks_service_endpoint" {
  description = "EKS service endpoint for API Gateway integration"
  type        = string
}

variable "create_api_key" {
  description = "Whether to create an API key"
  type        = bool
  default     = false
}

variable "api_key_value" {
  description = "API key value (optional)"
  type        = string
  default     = null
}

variable "product_id" {
  description = "Product ID for API Gateway"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}