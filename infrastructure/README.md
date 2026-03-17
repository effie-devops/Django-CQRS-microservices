# Django API Infrastructure - UAT Environment

This Terraform configuration deploys a Django API application on AWS ECS with the following components:

## Architecture
- **VPC** with public and private subnets across 2 AZs
- **Application Load Balancer** with SSL termination
- **ECS Fargate** cluster running Django containers
- **RDS PostgreSQL** database in private subnets
- **ECR** repository for Docker images
- **Route53** DNS records
- **ACM** SSL certificates
- **NAT Gateways** for outbound internet access from private subnets

## Prerequisites
1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Domain hosted in Route53 (effiecancode.buzz)
4. Docker image built and pushed to ECR

## Deployment Steps

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Plan the deployment:**
   ```bash
   terraform plan
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply
   ```

4. **Build and push Docker image:**
   ```bash
   # Get ECR login token
   aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 767398086791.dkr.ecr.eu-west-1.amazonaws.com

   # Build and tag image
   docker build -t django-api .
   docker tag django-api:latest 767398086791.dkr.ecr.eu-west-1.amazonaws.com/django-api:latest

   # Push image
   docker push 767398086791.dkr.ecr.eu-west-1.amazonaws.com/django-api:latest
   ```

## Configuration
- Environment: UAT
- Region: eu-west-1
- Domain: api.effiecancode.buzz
- Database: PostgreSQL 14

## Outputs
After deployment, you'll get:
- Website URL: https://api.effiecancode.buzz
- RDS endpoint (sensitive)
- ALB DNS name
- ECS cluster and service names