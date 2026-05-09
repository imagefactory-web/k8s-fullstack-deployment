# EKS Cluster Module
#
# Purpose: Create and configure an Amazon EKS cluster
#
# Resources to create:
# - EKS cluster
# - EKS node groups
# - IAM roles for cluster and nodes
# - Security groups
# - CloudWatch log group for control plane logs
resource "aws_eks_cluster" "this" {
   name     = var.cluster_name
   version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn
   vpc_config {
     subnet_ids              = var.private_subnet_ids
     endpoint_private_access = var.cluster_endpoint_private_access
     endpoint_public_access  = var.cluster_endpoint_public_access
     public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
   }
   enabled_cluster_log_types = [
     "api", "audit", "authenticator", "controllerManager", "scheduler"
   ]
   encryption_config {
     provider {
      key_arn = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
     }
    resources = ["secrets"]
   }
   depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster
   ]
# }
resource "aws_eks_node_group" "this" {
   for_each = var.node_groups
  cluster_name    = aws_eks_cluster.this.name
   node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
   subnet_ids      = var.private_subnet_ids
   scaling_config {
     desired_size = each.value.desired_size
     min_size     = each.value.min_size
     max_size     = each.value.max_size
   }
   instance_types = each.value.instance_types
   capacity_type  = lookup(each.value, "capacity_type", "ON_DEMAND")
   labels = lookup(each.value, "labels", {})
   taints = lookup(each.value, "taints", [])
   update_config {
     max_unavailable_percentage = 33
   }
   depends_on = [
    aws_iam_role_policy_attachment.node_policy
   ]
# }
# IAM roles and policies:
# - Cluster role with AmazonEKSClusterPolicy
- Node role with:
   * AmazonEKSWorkerNodePolicy
   * AmazonEKS_CNI_Policy
   * AmazonEC2ContainerRegistryReadOnly
#
# Outputs:
# - cluster_id
# - cluster_endpoint
# - cluster_security_group_id
# - oidc_issuer_url (for IRSA)
# - cluster_certificate_authority_data
