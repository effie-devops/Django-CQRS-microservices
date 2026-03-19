# create eks cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project_name}-${var.environment}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_app_subnet_az1.id,
      aws_subnet.private_app_subnet_az2.id,
      aws_subnet.public_subnet_az1.id,
      aws_subnet.public_subnet_az2.id
    ]
    security_group_ids      = [aws_security_group.app_server_security_group.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]

  tags = {
    Name                     = "${var.project_name}-${var.environment}-eks-cluster"
    "karpenter.sh/discovery" = "${var.project_name}-${var.environment}-cluster"
  }
}

# managed node group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.project_name}-${var.environment}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_app_subnet_az1.id, aws_subnet.private_app_subnet_az2.id]

  instance_types = [var.eks_node_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
    min_size     = var.eks_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-node-group"
  }
}

# cloudwatch log group for eks
resource "aws_cloudwatch_log_group" "log_group" {
  name = "/eks/${var.project_name}-${var.environment}-cluster"

  lifecycle {
    create_before_destroy = true
  }
}
