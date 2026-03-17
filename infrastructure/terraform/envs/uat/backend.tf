# store the terraform state file in s3 and lock with dynamodb
terraform {
  backend "s3" {
    bucket         = "django-cqrs-api-remote-state-bucket-north-virginia"
    key            = "uat/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
    profile        = "django-uat"
  }
}
