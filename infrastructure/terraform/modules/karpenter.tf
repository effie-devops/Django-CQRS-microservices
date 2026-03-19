# karpenter node iam role (used by nodes karpenter launches)
resource "aws_iam_role" "karpenter_node_role" {
  name = "${var.project_name}-${var.environment}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.project_name}-${var.environment}-karpenter-node-profile"
  role = aws_iam_role.karpenter_node_role.name
}

# karpenter controller iam role (IRSA)
resource "aws_iam_role" "karpenter_controller_role" {
  name = "${var.project_name}-${var.environment}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
          "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "karpenter_controller_policy" {
  name = "${var.project_name}-${var.environment}-karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:CreateTags",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node_role.arn
      },
      {
        Sid    = "InstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = aws_eks_cluster.eks_cluster.arn
      },
      {
        Sid    = "SSMGetParameter"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.region}::parameter/aws/service/*"
      },
      {
        Sid    = "PricingAccess"
        Effect = "Allow"
        Action = ["pricing:GetProducts"]
        Resource = "*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

# EKS access entry for karpenter nodes
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = aws_iam_role.karpenter_node_role.arn
  type          = "EC2_LINUX"
}

# SQS queue for spot interruption handling
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.project_name}-${var.environment}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2InterruptionPolicy"
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

# EventBridge rules for spot interruption, instance state changes, etc.
resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name = "${var.project_name}-${var.environment}-karpenter-instance-state-change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name = "${var.project_name}-${var.environment}-karpenter-spot-interruption"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}
