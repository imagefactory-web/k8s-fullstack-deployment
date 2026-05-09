# Terraform Configuration for Staging Environment
#
# Similar to dev but with production-like settings:
#
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = "staging"
      ManagedBy   = "Terraform"
      Project     = "eks-blueprint"
    }
  }
}
terraform {
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "staging/terraform.tfstate"
  }
}
module "networking" {
  source               = "../../modules/networking"
  environment          = "staging"
  cluster_name         = var.cluster_name
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
}
module "eks_cluster" {
  source             = "../../modules/eks-cluster"
  cluster_name       = var.cluster_name
  cluster_version    = "1.33"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  node_groups = {
    general = {
      desired_size   = 3
      min_size       = 2
      max_size       = 6
      instance_types = ["t3.large"]
    }
  }
}
