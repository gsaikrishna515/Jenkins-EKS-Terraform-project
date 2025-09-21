# --- EKS Cluster IAM Role ---
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# --- EKS Worker Node IAM Role ---
resource "aws_iam_role" "eks_nodes_role" {
  name = "${var.cluster_name}-nodes-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes_role.name
}
resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes_role.name
}
resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes_role.name
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}


# ---------------------------------------------------------------
# --- NEW SECTION: IAM Role for EBS CSI Driver ---
# ---------------------------------------------------------------

# This data source gets your cluster's OIDC provider URL, which is needed for IRSA.
data "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  cluster_name = aws_eks_cluster.eks_cluster.name
}

# IAM policy that grants the required permissions for the EBS CSI driver.
resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "${var.cluster_name}-ebs-csi-policy"
  description = "Allows EKS EBS CSI driver to manage volumes on behalf of the cluster."
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:DetachVolume",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:ModifyVolume"
        ],
        Resource = "*"
      }
    ]
  })
}

# IAM Role that the EBS CSI driver's service account will assume.
resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.cluster_name}-ebs-csi-role"

  # Trust relationship that allows the Kubernetes service account to assume this role.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
        },
        Action    = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # This condition limits the role assumption to the specific service account of the EBS driver.
            "${data.aws_iam_openid_connect_provider.eks_oidc_provider.url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# Attach the policy to the role.
resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  policy_arn = aws_iam_policy.ebs_csi_policy.arn
  role       = aws_iam_role.ebs_csi_role.name
}

# --- Associate the IAM Role with the EKS Add-on ---
# This tells the managed add-on to use the IAM role we just created.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name          = aws_eks_cluster.eks_cluster.name
  addon_name            = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_role.arn
  # Ensure this addon is managed after the role and OIDC provider are ready.
  depends_on = [
    aws_iam_role.ebs_csi_role,
    data.aws_iam_openid_connect_provider.eks_oidc_provider,
  ]
}


# --- EKS Node Group ---
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes_role.arn
  subnet_ids      = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  instance_types = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  # Ensure nodes can be managed by the cluster control plane
  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
  ]
}

