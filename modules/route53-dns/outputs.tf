# Route 53 DNS Module Outputs

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