module "django_infrastructure" {
  source = "../../modules"

  # Environment
  region                = var.region
  project_name          = var.project_name
  account_id            = var.account_id
  aws_profile           = var.aws_profile
  environment           = var.environment

  # VPC
  vpc_cidr                     = var.vpc_cidr
  public_subnet_az1_cidr       = var.public_subnet_az1_cidr
  public_subnet_az2_cidr       = var.public_subnet_az2_cidr
  private_app_subnet_az1_cidr  = var.private_app_subnet_az1_cidr
  private_app_subnet_az2_cidr  = var.private_app_subnet_az2_cidr
  private_data_subnet_az1_cidr = var.private_data_subnet_az1_cidr
  private_data_subnet_az2_cidr = var.private_data_subnet_az2_cidr

  # RDS
  db_user                      = var.db_user
  db_password                  = var.db_password
  db_name                      = var.db_name
  db_port                      = var.db_port
  multi_az_deployment          = var.multi_az_deployment
  database_instance_identifier = var.database_instance_identifier
  database_instance_class      = var.database_instance_class
  publicly_accessible          = var.publicly_accessible

  # ACM
  domain_name       = var.domain_name
  alternative_names = var.alternative_names

  # ECR
  image_name1  = var.image_name1
  image_name2  = var.image_name2

  # EKS
  eks_node_instance_type = var.eks_node_instance_type
  eks_node_desired_size  = var.eks_node_desired_size
  eks_node_min_size      = var.eks_node_min_size
  eks_node_max_size      = var.eks_node_max_size

  # GitHub
  github_repo = var.github_repo

  # Route53
  record_name          = var.record_name
  frontend_record_name = var.frontend_record_name

  # CloudFront
  enable_cloudfront = var.enable_cloudfront

  # WAF
  enable_waf = var.enable_waf

  # CloudWatch
  enable_cloudwatch = var.enable_cloudwatch

  # CloudTrail
  enable_cloudtrail = var.enable_cloudtrail

  # S3 for vpc flow logs
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
}
