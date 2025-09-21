variable "aws_region" {
  description = "AWS region for the EKS cluster"
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name for the EKS cluster"
  default     = "my-eks-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC"
  default     = "10.10.0.0/16"
}
