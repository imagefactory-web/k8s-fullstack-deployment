variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "create_service_account_roles" {
  description = "Optional list of service account roles to create"
  type        = list(string)
  default     = []
}
