# ECR Module
#
# Purpose: Create ECR repositories for container images
#
# Resources to create:
# - ECR repositories (one per application)
# - Repository policies
# - Lifecycle policies
resource "aws_ecr_repository" "this" {
   for_each = toset(var.repositories)
   name                 = "${var.environment}-${each.value}"
   image_tag_mutability = "MUTABLE" (or IMMUTABLE for prod)
   image_scanning_configuration {
     scan_on_push = true
   }
   encryption_configuration {
     encryption_type = "AES256" (or KMS for enhanced security)
   }
   tags = {
     Name        = each.value
     Environment = var.environment
   }
# }
# Lifecycle policy (keep last N images):
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
   repository = each.value.name
   policy = jsonencode({
     rules = [{
       rulePriority = 1
       description  = "Keep last 30 images"
       selection = {
         tagStatus     = "any"
         countType     = "imageCountMoreThan"
         countNumber   = 30
       }
       action = {
         type = "expire"
       }
     }]
   })
# }
# Repository policy (allow pull from EKS):
resource "aws_ecr_repository_policy" "this" {
  for_each   = aws_ecr_repository.this
   repository = each.value.name
   policy = jsonencode({
     Version = "2012-10-17"
     Statement = [{
       Sid    = "AllowPullFromEKS"
       Effect = "Allow"
       Principal = {
         Service = "eks.amazonaws.com"
       }
       Action = [
         "ecr:BatchCheckLayerAvailability",
         "ecr:GetDownloadUrlForLayer",
         "ecr:BatchGetImage"
       ]
     }]
   })
# }
# Outputs:
# - repository_urls (map of repo name to URL)
# - repository_arns
