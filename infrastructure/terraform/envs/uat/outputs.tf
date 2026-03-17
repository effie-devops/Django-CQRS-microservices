output "website_url" {
  description = "The URL of the deployed application"
  value       = module.django_infrastructure.website_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.django_infrastructure.rds_endpoint
  sensitive   = true
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.django_infrastructure.alb_dns_name
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.django_infrastructure.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.django_infrastructure.eks_cluster_endpoint
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.django_infrastructure.alb_controller_role_arn
}

output "ecr_repository_reader_url" {
  description = "ECR repository URL for reader service"
  value       = module.django_infrastructure.ecr_repository_reader_url
}

output "ecr_repository_writer_url" {
  description = "ECR repository URL for writer service"
  value       = module.django_infrastructure.ecr_repository_writer_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.django_infrastructure.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.django_infrastructure.cloudfront_domain_name
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.django_infrastructure.waf_web_acl_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = module.django_infrastructure.cloudwatch_log_group_name
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = module.django_infrastructure.cloudtrail_arn
}

output "vpc_flow_logs_bucket_name" {
  description = "VPC Flow Logs S3 bucket name"
  value       = module.django_infrastructure.vpc_flow_logs_bucket_name
}

output "vpc_flow_log_id" {
  description = "VPC Flow Log ID"
  value       = module.django_infrastructure.vpc_flow_log_id
}
