# EKS Cluster Module Outputs

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group that was created by default"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "kubeconfig_certificate_authority_data" {
  description = "Nested attribute containing certificate-authority-data for your cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_arns" {
  description = "The ARNs of the node groups"
  value       = { for ng in aws_eks_node_group.this : ng.id => ng.arn }
}

output "node_group_ids" {
  description = "The IDs of the node groups"
  value       = keys(aws_eks_node_group.this)
}

output "iam_role_arn" {
  description = "The ARN of the IAM role used by the cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_group_role_arn" {
  description = "The ARN of the IAM role used by the node groups"
  value       = aws_iam_role.node_group.arn
}