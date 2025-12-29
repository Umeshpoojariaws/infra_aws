# API Gateway Module
# Creates an API Gateway with integration to EKS services

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

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = var.description

  endpoint_configuration {
    types = ["PRIVATE"]
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:*:*:*/*/*/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = ["0.0.0.0/0"]
          }
        }
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:*:*:*/*/*/*"
        Condition = {
          StringNotEquals = {
            "aws:VpcSourceVpce" = var.vpc_endpoint_id
          }
        }
      }
    ]
  })

  tags = merge({
    Name        = var.api_name
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create VPC Link for private integration
resource "aws_api_gateway_vpc_link" "this" {
  name        = "${var.api_name}-vpc-link"
  description = "VPC Link for ${var.api_name}"
  target_arns = var.subnet_ids

  tags = merge({
    Name        = "${var.api_name}-vpc-link"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create resource for API
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"

  tags = merge({
    Name        = "${var.api_name}-proxy-resource"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create method for proxy resource
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  tags = merge({
    Name        = "${var.api_name}-proxy-method"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create integration for proxy resource
resource "aws_api_gateway_integration" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  type                    = "HTTP_PROXY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.this.id
  integration_http_method = "ANY"
  uri                       = "http://${var.eks_service_endpoint}/{proxy}"

  tags = merge({
    Name        = "${var.api_name}-proxy-integration"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create root resource method
resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"

  tags = merge({
    Name        = "${var.api_name}-root-method"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create root resource integration
resource "aws_api_gateway_integration" "root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_rest_api.this.root_resource_id
  http_method = aws_api_gateway_method.root.http_method

  type                    = "HTTP_PROXY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.this.id
  integration_http_method = "ANY"
  uri                       = "http://${var.eks_service_endpoint}/"

  tags = merge({
    Name        = "${var.api_name}-root-integration"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Deploy API
resource "aws_api_gateway_deployment" "this" {
  depends_on = [aws_api_gateway_integration.proxy, aws_api_gateway_integration.root]

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.stage_name

  tags = merge({
    Name        = "${var.api_name}-deployment"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create usage plan
resource "aws_api_gateway_usage_plan" "this" {
  name         = "${var.api_name}-usage-plan"
  description  = "Usage plan for ${var.api_name}"
  product_id   = var.product_id

  quota_settings {
    limit    = 5000
    period   = "MONTH"
    offset   = 0
  }

  throttle_settings {
    burst_limit = 200
    rate_limit  = 100
  }

  tags = merge({
    Name        = "${var.api_name}-usage-plan"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create usage plan stage association
resource "aws_api_gateway_usage_plan_stage" "this" {
  usage_plan_id = aws_api_gateway_usage_plan.this.id
  stage_id      = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.this.id

  tags = merge({
    Name        = "${var.api_name}-usage-plan-stage"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create API key (optional)
resource "aws_api_gateway_api_key" "this" {
  count = var.create_api_key ? 1 : 0

  name  = "${var.api_name}-api-key"
  value = var.api_key_value

  tags = merge({
    Name        = "${var.api_name}-api-key"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create API key usage plan association
resource "aws_api_gateway_usage_plan_key" "this" {
  count = var.create_api_key ? 1 : 0

  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id

  tags = merge({
    Name        = "${var.api_name}-usage-plan-key"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Outputs
output "rest_api_id" {
  description = "The ID of the REST API"
  value       = aws_api_gateway_rest_api.this.id
}

output "rest_api_name" {
  description = "The name of the REST API"
  value       = aws_api_gateway_rest_api.this.name
}

output "vpc_link_id" {
  description = "The ID of the VPC Link"
  value       = aws_api_gateway_vpc_link.this.id
}

output "deployment_id" {
  description = "The ID of the deployment"
  value       = aws_api_gateway_deployment.this.id
}

output "stage_name" {
  description = "The name of the stage"
  value       = aws_api_gateway_deployment.this.stage_name
}

output "invoke_url" {
  description = "The invoke URL of the API"
  value       = aws_api_gateway_deployment.this.invoke_url
}

output "usage_plan_id" {
  description = "The ID of the usage plan"
  value       = aws_api_gateway_usage_plan.this.id
}

output "api_key" {
  description = "The API key (if created)"
  value       = var.create_api_key ? aws_api_gateway_api_key.this[0].id : null
  sensitive   = true
}