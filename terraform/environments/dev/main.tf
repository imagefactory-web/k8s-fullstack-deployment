# Terraform Configuration for Development Environment
#
# Purpose: Create development EKS cluster and supporting infrastructure
#
#Provider configuration:
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "eks-arc-runner"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terraform"
      Project     = "eks-blueprint"
    }
  }
}
# Module calls:
module "networking" {
  source               = "../../modules/networking"
  environment          = "dev"
  cluster_name         = var.cluster_name
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
}
module "eks_cluster" {
  source             = "../../modules/eks-cluster"
  cluster_name       = var.cluster_name
  cluster_version    = "1.28"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.medium"]
    }
  }
}
module "iam" {
  source                  = "../../modules/iam"
  environment             = "dev"
  cluster_oidc_issuer_url = module.eks_cluster.oidc_issuer_url
}
module "ecr" {
  source       = "../../modules/ecr"
  environment  = "dev"
  repositories = ["frontend", "backend"]
}
# Outputs:
# - VPC ID
# - EKS cluster name
# - EKS cluster endpoint
# - ECR repository URLs
