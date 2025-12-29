# RDS Database Module Variables

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