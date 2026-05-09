# IAM Module for EKS IRSA (IAM Roles for Service Accounts)
#
# Purpose: Create IAM roles that can be assumed by Kubernetes service accounts
#
# OIDC Provider setup:
data "tls_certificate" "cluster" {
  url = var.cluster_oidc_issuer_url
}
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = var.cluster_oidc_issuer_url
}
# Service account roles to create:
# 1. EBS CSI Driver role
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.environment}-ebs-csi-driver-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}
# 2. AWS Load Balancer Controller role
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.environment}-aws-lb-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}
# 3. Cluster Autoscaler role
# 4. External DNS role
# 5. Application-specific roles (frontend, backend)
# Attach appropriate IAM policies to each role:
# - EBS CSI: AWS managed policy for EBS CSI driver
# - ALB Controller: Policy for managing ALBs/NLBs
# - Cluster Autoscaler: Policy for ASG operations
# - External DNS: Policy for Route53 management
# - App roles: S3, RDS, Secrets Manager access as needed
# Outputs:
# - oidc_provider_arn
# - role_arns (map of role names to ARNs)
