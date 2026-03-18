# environment variables
variable "region" {
  description = "region to create resources"
  type        = string
}

variable "project_name" {
  description = "project name"
  type        = string
}

variable "account_id" {
  description = "aws account id"
  type        = string
}

variable "aws_profile" {
  description = "aws cli profile"
  type        = string
}

variable "environment" {
  description = "environment"
  type        = string
}

# vpc variables
variable "vpc_cidr" {
  description = "vpc cidr block"
  type        = string
}

variable "public_subnet_az1_cidr" {
  description = "public subnet az1 cidr block"
  type        = string
}

variable "public_subnet_az2_cidr" {
  description = "public subnet az2 cidr block"
  type        = string
}

variable "private_app_subnet_az1_cidr" {
  description = "private app subnet az1 cidr block"
  type        = string
}

variable "private_app_subnet_az2_cidr" {
  description = "private app subnet az2 cidr block"
  type        = string
}

variable "private_data_subnet_az1_cidr" {
  description = "private data subnet az1 cidr block"
  type        = string
}

variable "private_data_subnet_az2_cidr" {
  description = "private data subnet az2 cidr block"
  type        = string
}

# ecr variables
variable "image_name1" {
  description = "ecr image name"
  type        = string
}

variable "image_name2" {
  description = "ecr image name"
  type        = string
}

# rds variables
variable "db_user" {
  description = "db username"
  type        = string
}

variable "db_password" {
  description = "db password"
  type        = string
}

variable "db_name" {
  description = "rds db name"
  type        = string
}

variable "db_port" {
  description = "rds db port"
  type        = number
}

variable "multi_az_deployment" {
  description = "create a standby db instance"
  type        = bool
}

variable "database_instance_identifier" {
  description = "database instance identifier"
  type        = string
}

variable "database_instance_class" {
  description = "database instance type"
  type        = string
}

variable "publicly_accessible" {
  description = "controls if instance is publicly accessible"
  type        = bool
}

# acm variables
variable "domain_name" {
  description = "domain name"
  type        = string
}

variable "alternative_names" {
  description = "sub domain name"
  type        = string
}

# eks variables
variable "eks_node_instance_type" {
  description = "eks node group instance type"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired_size" {
  description = "desired number of eks nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "minimum number of eks nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "maximum number of eks nodes"
  type        = number
  default     = 4
}

# route-53 variables
variable "record_name" {
  description = "sub domain name"
  type        = string
}

variable "frontend_record_name" {
  description = "frontend sub domain name"
  type        = string
}

# cloudfront variables
variable "enable_cloudfront" {
  description = "enable cloudfront distribution"
  type        = bool
  default     = true
}

# waf variables
variable "enable_waf" {
  description = "enable waf web acl"
  type        = bool
  default     = true
}

# cloudwatch variables
variable "enable_cloudwatch" {
  description = "enable cloudwatch monitoring"
  type        = bool
  default     = true
}

# cloudtrail variables
variable "enable_cloudtrail" {
  description = "enable cloudtrail logging"
  type        = bool
  default     = true
}

# s3 variables
variable "enable_vpc_flow_logs" {
  description = "enable vpc flow logs to s3"
  type        = bool
  default     = true
}

# github variables
variable "github_repo" {
  description = "github repo in format owner/repo"
  type        = string
}
