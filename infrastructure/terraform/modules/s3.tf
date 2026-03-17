# S3 Bucket for VPC Flow Logs
resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  bucket        = "${var.project_name}-${var.environment}-vpc-flow-logs-${random_string.flow_logs_suffix.result}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  }
}

resource "random_string" "flow_logs_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_policy" "vpc_flow_logs_bucket_policy" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.vpc_flow_logs_bucket.arn}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.vpc_flow_logs_bucket.arn
      }
    ]
  })
}

# VPC Flow Logs
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_s3_bucket.vpc_flow_logs_bucket.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-log"
  }

  depends_on = [aws_s3_bucket_policy.vpc_flow_logs_bucket_policy]
}