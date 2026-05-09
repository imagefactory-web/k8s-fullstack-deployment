# EKS Blueprint Setup Guide

This guide provides step-by-step instructions to set up and deploy the complete EKS blueprint infrastructure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Structure](#repository-structure)
3. [Infrastructure Setup](#infrastructure-setup)
4. [Application Deployment](#application-deployment)
5. [GitOps with ArgoCD](#gitops-with-argocd)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **AWS CLI** (v2.x): [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (v1.6+): [Installation Guide](https://developer.hashicorp.com/terraform/install)
- **kubectl** (v1.28+): [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Helm** (v3.13+): [Installation Guide](https://helm.sh/docs/intro/install/)
- **Docker**: [Installation Guide](https://docs.docker.com/get-docker/)
- **ArgoCD CLI** (optional): [Installation Guide](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

### AWS Account Setup

- AWS account with appropriate IAM permissions
- S3 bucket for Terraform state storage
- DynamoDB table for Terraform state locking
- ECR repositories for container images

### Required Permissions

IAM user/role needs:
- EC2, VPC, EKS management
- S3 access for state storage
- ECR push/pull permissions
- Route53 (if using external-dns)
- ACM (for TLS certificates)

## Repository Structure

```
app-eks-blueprint/
├── apps/              # Application source code
├── charts/            # Helm charts for deployments
├── terraform/         # Infrastructure as Code
├── argocd/           # GitOps configuration
├── .github/          # CI/CD workflows
└── docs/             # Documentation
```

## Infrastructure Setup

### Step 1: Configure Terraform Backend

Create S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 2: Deploy Development Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

This creates:
- VPC with public and private subnets
- EKS cluster with managed node groups
- ECR repositories
- IAM roles for service accounts (IRSA)

### Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name eks-blueprint-dev \
  --region us-east-1

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 4: Install Core Add-ons

```bash
# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-blueprint-dev

# Install EBS CSI Driver
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  -n kube-system

# Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Application Deployment

### Step 5: Build and Push Container Images

```bash
# Build frontend
cd apps/frontend
docker build -t frontend:latest .

# Tag and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag frontend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/dev-frontend:v1.0.0
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/dev-frontend:v1.0.0

# Repeat for backend
cd ../backend
docker build -t backend:latest .
docker tag backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/dev-backend:v1.0.0
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/dev-backend:v1.0.0
```

### Step 6: Deploy with Helm (Manual)

```bash
# Create namespaces
kubectl create namespace frontend-dev
kubectl create namespace backend-dev

# Deploy frontend
helm install frontend-dev charts/frontend \
  -n frontend-dev \
  -f charts/frontend/values-dev.yaml

# Deploy backend
helm install backend-dev charts/backend \
  -n backend-dev \
  -f charts/backend/values-dev.yaml

# Check deployments
kubectl get rollouts -A
kubectl get pods -A
```

## GitOps with ArgoCD

### Step 7: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Step 8: Access ArgoCD UI

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login via CLI
argocd login localhost:8080 --username admin --password <password>
```

### Step 9: Configure ArgoCD Applications

```bash
# Create ArgoCD project
kubectl apply -f argocd/projects/platform-project.yaml

# Deploy root application (App of Apps)
kubectl apply -f argocd/apps/root-app.yaml

# Deploy environment-specific apps
kubectl apply -f argocd/apps/dev-apps.yaml
kubectl apply -f argocd/apps/staging-apps.yaml
kubectl apply -f argocd/apps/prod-apps.yaml

# Check ArgoCD applications
argocd app list
```

## CI/CD Pipeline

### Step 10: Configure GitHub Actions

1. **Set up GitHub Secrets:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_ROLE_ARN` (for OIDC)
   - `GITHUB_TOKEN` (automatically provided)

2. **Workflows:**
   - `ci-build-push.yaml`: Builds and pushes container images
   - `ci-helm-release.yaml`: Packages and releases Helm charts
   - `cd-deploy.yaml`: Updates image tags for GitOps
   - `terraform-plan-apply.yaml`: Manages infrastructure

3. **Trigger a build:**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin main
   ```

### Step 11: GitOps Deployment Flow

1. Developer pushes code to GitHub
2. GitHub Actions builds and pushes image to ECR
3. GitHub Actions updates Helm values file with new image tag
4. ArgoCD detects changes and syncs to cluster
5. Argo Rollouts performs blue-green deployment
6. Manual or automated promotion after verification

## Monitoring and Observability

### Step 12: Install Monitoring Stack

```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f charts/infrastructure/kube-prometheus-stack/values.yaml

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80

# Default credentials: admin/prom-operator
```

### Step 13: Install Linkerd (Service Mesh)

```bash
# Install Linkerd CLI
curl -sL https://run.linkerd.io/install | sh

# Install Linkerd control plane
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# Verify installation
linkerd check

# Install Linkerd Viz for observability
linkerd viz install | kubectl apply -f -

# Inject Linkerd into namespaces
kubectl annotate namespace frontend-dev linkerd.io/inject=enabled
kubectl annotate namespace backend-dev linkerd.io/inject=enabled

# Restart pods to inject sidecar
kubectl rollout restart deployment -n frontend-dev
kubectl rollout restart deployment -n backend-dev
```

### Step 14: Configure Dashboards and Alerts

1. **Grafana Dashboards:**
   - Import pre-built dashboards for Kubernetes, applications
   - Create custom dashboards for business metrics

2. **Prometheus Alerts:**
   - Configure alert rules in PrometheusRule CRDs
   - Set up Alertmanager for notifications (Slack, PagerDuty)

3. **Linkerd Dashboard:**
   ```bash
   linkerd viz dashboard
   ```

## Troubleshooting

### Common Issues

**1. Pods not starting:**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**2. ArgoCD sync failures:**
```bash
argocd app get <app-name>
argocd app sync <app-name>
kubectl get events -n <namespace>
```

**3. Terraform state lock:**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**4. ECR authentication:**
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Useful Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# View ArgoCD apps
argocd app list
argocd app sync <app-name>

# Check rollout status
kubectl argo rollouts get rollout <rollout-name> -n <namespace>
kubectl argo rollouts promote <rollout-name> -n <namespace>

# View logs
kubectl logs -f <pod-name> -n <namespace>

# Port forward services
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>
```

## Best Practices

1. **Security:**
   - Use IRSA for pod-level AWS permissions
   - Enable pod security policies
   - Scan images for vulnerabilities
   - Rotate credentials regularly

2. **High Availability:**
   - Deploy across multiple availability zones
   - Use Pod Disruption Budgets
   - Configure proper resource requests/limits
   - Enable autoscaling (HPA, Cluster Autoscaler)

3. **Monitoring:**
   - Set up comprehensive metrics and logging
   - Configure alerts for critical issues
   - Use distributed tracing
   - Regular performance reviews

4. **GitOps:**
   - All changes via Git
   - Use separate branches for environments
   - Implement approval workflows for production
   - Tag releases properly

## Next Steps

1. Configure custom domains and SSL certificates
2. Set up disaster recovery and backup procedures
3. Implement cost optimization strategies
4. Establish incident response procedures
5. Create runbooks for common operations

## Resources

- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Linkerd Documentation](https://linkerd.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)

## Support

For issues and questions:
- Create an issue in this repository
- Contact the platform team
- Check internal documentation wiki
