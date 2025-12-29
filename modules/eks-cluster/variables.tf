# EKS Cluster Module Variables

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account" {
  description = "Account type (app, ml, shared)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the cluster"
  type        = string
  default     = null
}

variable "node_groups" {
  description = "Map of node groups to create"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    max_size       = number
    min_size       = number
    disk_size      = number
    labels         = map(string)
    tags           = map(string)
  }))
  default = {
    main = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      max_size       = 4
      min_size       = 1
      disk_size      = 20
      labels         = {}
      tags           = {}
    }
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}