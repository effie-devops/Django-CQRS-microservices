# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks_log_group" {
  name              = "/eks/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-logs"
  }
}

# CloudWatch Alarms for ALB
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB response time"

  dimensions = {
    LoadBalancer = aws_lb.application_load_balancer.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-response-time-alarm"
  }
}

# CloudWatch Alarm for EKS Node CPU
resource "aws_cloudwatch_metric_alarm" "eks_cpu_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-eks-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS node CPU utilization"

  dimensions = {
    ClusterName = aws_eks_cluster.eks_cluster.name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cpu-alarm"
  }
}
