# RDS Database Module
# Creates an RDS instance with automated Kubernetes secrets and config maps

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for Kubernetes integration"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the database"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the database"
  type        = list(string)
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "username" {
  description = "Master username"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "Master password (optional, will generate if not provided)"
  type        = string
  default     = null
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Kubernetes namespace for secrets and config maps"
  type        = string
  default     = "default"
}

variable "kubernetes_host" {
  description = "Kubernetes API server host"
  type        = string
}

variable "kubernetes_ca_certificate" {
  description = "Kubernetes CA certificate"
  type        = string
}

variable "kubernetes_token" {
  description = "Kubernetes authentication token"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Generate random password if not provided
resource "random_password" "db_password" {
  count = var.password == null ? 1 : 0

  length  = 16
  special = true
}

# Create security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.env}-${var.account}-rds"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name        = "${var.env}-${var.account}-rds-sg"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create subnet group
resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-${var.account}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge({
    Name        = "${var.env}-${var.account}-rds-subnet-group"
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Create RDS instance
resource "aws_db_instance" "this" {
  identifier     = var.db_name
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.username
  password = var.password != null ? var.password : random_password.db_password[0].result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.db_name}-final-snapshot"

  multi_az = var.multi_az

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = merge({
    Name        = var.db_name
    Environment = var.env
    Account     = var.account
  }, var.tags)
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = base64decode(var.kubernetes_ca_certificate)
  token                  = var.kubernetes_token
}

# Create Kubernetes secret for database credentials
resource "kubernetes_secret" "db_creds" {
  metadata {
    name      = "${var.cluster_name}-db-secret"
    namespace = var.namespace
    labels = {
      app         = var.db_name
      environment = var.env
      account     = var.account
    }
  }

  data = {
    username = var.username
    password = var.password != null ? var.password : random_password.db_password[0].result
  }

  type = "Opaque"

  depends_on = [aws_db_instance.this]
}

# Create Kubernetes config map for database connection
resource "kubernetes_config_map" "db_config" {
  metadata {
    name      = "${var.cluster_name}-db-config"
    namespace = var.namespace
    labels = {
      app         = var.db_name
      environment = var.env
      account     = var.account
    }
  }

  data = {
    host       = aws_db_instance.this.endpoint
    port       = aws_db_instance.this.port
    database   = var.database_name != null ? var.database_name : var.db_name
    engine     = var.engine
    connection_string = "${var.engine}://${var.username}:${var.password != null ? var.password : random_password.db_password[0].result}@${aws_db_instance.this.endpoint}:${aws_db_instance.this.port}/${var.database_name != null ? var.database_name : var.db_name}"
  }

  depends_on = [kubernetes_secret.db_creds]
}

# Apply manifests to cluster (triggers on change)
resource "null_resource" "apply_manifests" {
  provisioner "local-exec" {
    command = "kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${var.cluster_name}-db-secret
  namespace: ${var.namespace}
  labels:
    app: ${var.db_name}
    environment: ${var.env}
    account: ${var.account}
type: Opaque
data:
  username: ${base64encode(var.username)}
  password: ${base64encode(var.password != null ? var.password : random_password.db_password[0].result)}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${var.cluster_name}-db-config
  namespace: ${var.namespace}
  labels:
    app: ${var.db_name}
    environment: ${var.env}
    account: ${var.account}
data:
  host: ${aws_db_instance.this.endpoint}
  port: ${aws_db_instance.this.port}
  database: ${var.database_name != null ? var.database_name : var.db_name}
  engine: ${var.engine}
  connection_string: ${var.engine}://${var.username}:${var.password != null ? var.password : random_password.db_password[0].result}@${aws_db_instance.this.endpoint}:${aws_db_instance.this.port}/${var.database_name != null ? var.database_name : var.db_name}
EOF"
  }

  triggers = {
    secret_hash  = sha256(jsonencode(kubernetes_secret.db_creds.data))
    config_hash  = sha256(jsonencode(kubernetes_config_map.db_config.data))
    endpoint     = aws_db_instance.this.endpoint
    port         = aws_db_instance.this.port
  }

  depends_on = [kubernetes_secret.db_creds, kubernetes_config_map.db_config]
}

# Outputs
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