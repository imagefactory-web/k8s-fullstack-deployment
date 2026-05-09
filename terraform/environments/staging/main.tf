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
# }
# backend "s3" {
   bucket = "terraform-state-bucket"
   key    = "staging/terraform.tfstate"
# }
module "networking" {
   source = "../../modules/networking"
   environment = "staging"
   vpc_cidr = "10.1.0.0/16"
   availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
   private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
   public_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
# }
module "eks_cluster" {
   source = "../../modules/eks-cluster"
   environment = "staging"
   cluster_version = "1.28"
   node_groups = {
     general = {
       desired_size = 3
       min_size = 2
       max_size = 6
       instance_types = ["t3.large"]
     }
   }
# }
