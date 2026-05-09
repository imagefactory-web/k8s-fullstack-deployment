# Variables for Development Environment
#
variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-blueprint-dev"
}
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
