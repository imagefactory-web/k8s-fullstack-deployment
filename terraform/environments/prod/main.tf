# Terraform Configuration for Production Environment
#
P#roduction-ready configuration with:
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
# }
# backend "s3" {
   bucket = "terraform-state-bucket"
   key    = "prod/terraform.tfstate"
# }
module "networking" {
   source = "../../modules/networking"
   environment = "prod"
   vpc_cidr = "10.2.0.0/16"
   availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
   enable_nat_gateway = true
   single_nat_gateway = false (one per AZ for HA)
   enable_vpc_flow_logs = true
# }
module "eks_cluster" {
   source = "../../modules/eks-cluster"
   environment = "prod"
   cluster_version = "1.28"
   cluster_endpoint_private_access = true
   cluster_endpoint_public_access = true (restrict CIDR blocks)
   node_groups = {
     system = {
       desired_size = 3
       min_size = 3
       max_size = 5
       instance_types = ["t3.large"]
       labels = { workload-type = "system" }
       taints = [{
         key = "workload-type"
         value = "system"
         effect = "NoSchedule"
       }]
     }
     application = {
       desired_size = 5
       min_size = 3
       max_size = 20
       instance_types = ["m5.xlarge"]
       labels = { workload-type = "application" }
     }
   }
   enable_cluster_autoscaler = true
   enable_cluster_encryption = true
# }
module "iam" {
   source = "../../modules/iam"
   environment = "prod"
   create_service_account_roles = [
     "frontend-prod",
     "backend-prod",
     "prometheus"
   ]
# }
