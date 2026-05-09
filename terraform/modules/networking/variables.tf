variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster for tagging"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to create subnets in"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Whether to deploy a single NAT gateway instead of one per AZ"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Whether NAT gateways should be enabled"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC flow logs"
  type        = bool
  default     = false
}
