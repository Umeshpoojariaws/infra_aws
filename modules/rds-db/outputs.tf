# RDS Database Module Outputs

output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "The connection endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_port" {
  description = "The port on which to connect to the database"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The database name"
  value       = var.database_name != null ? var.database_name : var.db_name
}

output "db_username" {
  description = "The master username"
  value       = var.username
}

output "db_password" {
  description = "The master password"
  value       = var.password != null ? var.password : random_password.db_password[0].result
  sensitive   = true
}

output "security_group_id" {
  description = "The security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}

output "subnet_group_name" {
  description = "The RDS subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "kubernetes_secret_name" {
  description = "The name of the Kubernetes secret containing database credentials"
  value       = "${var.cluster_name}-db-secret"
}

output "kubernetes_config_map_name" {
  description = "The name of the Kubernetes config map containing database configuration"
  value       = "${var.cluster_name}-db-config"
}