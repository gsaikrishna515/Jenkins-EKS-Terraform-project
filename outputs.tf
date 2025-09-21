output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "region" {
  value = var.aws_region
}
