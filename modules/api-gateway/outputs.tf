# API Gateway Module Outputs

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