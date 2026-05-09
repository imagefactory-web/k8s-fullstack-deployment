# Terraform Configuration for Production Environment
#
# Production-ready configuration with:
# - Multi-AZ setup (3 AZs)
# - Larger instance types
# - Multiple node groups
# - Enhanced monitoring
# - Backup configuration
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "Terraform"
      Project     = "eks-blueprint"
      CostCenter  = "engineering"
    }
  }
}
terraform {
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "prod/terraform.tfstate"
  }
}
module "networking" {
  source               = "../../modules/networking"
  environment          = "prod"
  cluster_name         = var.cluster_name
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = false # one per AZ for HA
  enable_vpc_flow_logs = true
}
module "eks_cluster" {
  source                          = "../../modules/eks-cluster"
  cluster_name                    = var.cluster_name
  cluster_version                 = "1.33"
  vpc_id                          = module.networking.vpc_id
  private_subnet_ids              = module.networking.private_subnet_ids
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true # restrict CIDR blocks
  node_groups = {
    system = {
      desired_size   = 3
      min_size       = 3
      max_size       = 5
      instance_types = ["t3.large"]
      labels         = { workload-type = "system" }
      taints = [{
        key    = "workload-type"
        value  = "system"
        effect = "NoSchedule"
      }]
    }
    application = {
      desired_size   = 5
      min_size       = 3
      max_size       = 20
      instance_types = ["m5.xlarge"]
      labels         = { workload-type = "application" }
    }
  }
  enable_cluster_encryption = true
}
module "iam" {
  source                  = "../../modules/iam"
  environment             = "prod"
  cluster_oidc_issuer_url = module.eks_cluster.oidc_issuer_url
}
