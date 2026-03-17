# eks outputs
output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_certificate_authority" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_node_group_name" {
  value = aws_eks_node_group.eks_node_group.node_group_name
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller_role.arn
}

# rds endpoint
output "rds_endpoint" {
  value = aws_db_instance.database_instance.endpoint
}

# domain name
output "domain_name" {
  value = join("", [var.record_name, ".", var.domain_name])
}

# website url
output "website_url" {
  value = join("", ["https://", var.record_name, ".", var.domain_name])
}

# alb dns name
output "alb_dns_name" {
  value = aws_lb.application_load_balancer.dns_name
}

# ecr repository urls
output "ecr_repository_reader_url" {
  value = aws_ecr_repository.ecr_repository_reader.repository_url
}

output "ecr_repository_writer_url" {
  value = aws_ecr_repository.ecr_repository_writer.repository_url
}

# cloudfront distribution id
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

# cloudfront domain name
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.main.domain_name
}

# waf web acl arn
output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}

# cloudwatch log group name
output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.eks_log_group.name
}

# cloudtrail arn
output "cloudtrail_arn" {
  value = aws_cloudtrail.main.arn
}

# vpc flow logs bucket name
output "vpc_flow_logs_bucket_name" {
  value = aws_s3_bucket.vpc_flow_logs_bucket.bucket
}

# vpc flow log id
output "vpc_flow_log_id" {
  value = aws_flow_log.vpc_flow_log.id
}

# secrets manager
output "secrets_access_role_arn" {
  value = aws_iam_role.secrets_access_role.arn
}

output "db_credentials_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
