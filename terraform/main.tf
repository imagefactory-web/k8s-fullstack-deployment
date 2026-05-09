# This ensures state is ALWAYS synced with S3
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "eks-arc-runner"           # Your configured bucket
    key            = "eks-arc-runner/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true                    # Encrypt state file
    dynamodb_table = "terraform-locks"       # Prevent concurrent modifications
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = "student-lab"
      Project     = "eks-arc-runner"
    }
  }
}