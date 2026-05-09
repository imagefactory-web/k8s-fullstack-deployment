# Networking Module
#
# Purpose: Create VPC and networking infrastructure for EKS
#
# Resources to create:
# - VPC
# - Public subnets (for load balancers)
# - Private subnets (for EKS nodes)
# - Internet Gateway
# - NAT Gateways (one per AZ for HA)
# - Route tables and associations
# - VPC Flow Logs (optional)
resource "aws_vpc" "this" {
   cidr_block           = var.vpc_cidr
   enable_dns_hostnames = true
   enable_dns_support   = true
   tags = {
     Name = "${var.environment}-vpc"
     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
   }
# }
resource "aws_subnet" "private" {
   count = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
   cidr_block        = var.private_subnet_cidrs[count.index]
   availability_zone = var.availability_zones[count.index]
   tags = {
     Name = "${var.environment}-private-${var.availability_zones[count.index]}"
     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
     "kubernetes.io/role/internal-elb" = "1"
   }
# }
resource "aws_subnet" "public" {
   count = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
   cidr_block              = var.public_subnet_cidrs[count.index]
   availability_zone       = var.availability_zones[count.index]
   map_public_ip_on_launch = true
   tags = {
     Name = "${var.environment}-public-${var.availability_zones[count.index]}"
     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
     "kubernetes.io/role/elb" = "1"
   }
# }
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
# }
resource "aws_eip" "nat" {
   count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
   domain = "vpc"
# }
resource "aws_nat_gateway" "this" {
   count         = var.single_nat_gateway ? 1 : length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on = [aws_internet_gateway.this]
# }
# Route tables:
# - Public route table (routes to IGW)
# - Private route tables (routes to NAT Gateway)
# VPC Endpoints (optional for private cluster):
# - S3 (Gateway endpoint)
# - ECR API & DKR (Interface endpoints)
# - EC2, STS (Interface endpoints)
# Outputs:
# - vpc_id
# - private_subnet_ids
# - public_subnet_ids
# - nat_gateway_ips
