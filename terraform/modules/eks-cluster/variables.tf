variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID for cluster networking"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS cluster endpoint should be privately accessible"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS cluster endpoint should be publicly accessible"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS cluster public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_encryption" {
  description = "Whether EKS cluster secrets should be encrypted with KMS"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Whether cluster autoscaler support should be enabled"
  type        = bool
  default     = false
}

variable "node_groups" {
  description = "Node group configuration map"
  type        = map(any)
}
