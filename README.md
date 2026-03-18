# Django CQRS Microservices — Platform Documentation

A CQRS (Command Query Responsibility Segregation) architecture running two Django microservices on Amazon EKS, with CI/CD via GitHub Actions, secrets managed by AWS Secrets Manager, and traffic routed through an ALB Ingress.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Infrastructure (Terraform)](#infrastructure-terraform)
  - [Secrets Manager](#secrets-manager)
  - [GitHub Actions OIDC Role](#github-actions-oidc-role)
  - [EKS Access Entry](#eks-access-entry)
  - [Security Groups](#security-groups)
- [Platform (Kubernetes)](#platform-kubernetes)
  - [Secrets Flow](#secrets-flow)
  - [Reader Service](#reader-service)
  - [Writer Service](#writer-service)
  - [Ingress](#ingress)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Triggers](#triggers)
  - [Pipeline Flow](#pipeline-flow)
  - [Required GitHub Secrets](#required-github-secrets)
- [API Endpoints](#api-endpoints)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
                         ┌──────────────────────────────┐
                         │   apis.effiecancode.buzz      │
                         │        (Route 53)             │
                         └──────────────┬───────────────┘
                                        │
                         ┌──────────────▼───────────────┐
                         │     ALB (Ingress Controller)  │
                         │     TLS via ACM Certificate   │
                         └──────┬───────────────┬───────┘
                                │               │
                         /reader/*        /writer/*
                                │               │
                    ┌───────────▼──┐    ┌───────▼────────┐
                    │ Reader Svc   │    │  Writer Svc    │
                    │ (ClusterIP)  │    │  (ClusterIP)   │
                    │  port 80     │    │   port 80      │
                    └──────┬───────┘    └───────┬────────┘
                           │                    │
                    ┌──────▼───────┐    ┌───────▼────────┐
                    │ Reader Pods  │    │  Writer Pods   │
                    │ (2-6 replicas│    │  (2-6 replicas)│
                    │  via HPA)    │    │   via HPA)     │
                    └──────┬───────┘    └───────┬────────┘
                           │                    │
                           └────────┬───────────┘
                                    │
                    ┌───────────────▼───────────────────┐
                    │  AWS Secrets Manager               │
                    │  (DB credentials via CSI Driver)   │
                    └───────────────┬───────────────────┘
                                    │
                    ┌───────────────▼───────────────────┐
                    │         Amazon RDS (PostgreSQL)    │
                    └───────────────────────────────────┘
```

---

## Project Structure

```
Django-CQRS-microservices/
├── .github/workflows/
│   └── docker-image.yml            # CI/CD pipeline
├── app/
│   ├── reader-service/reader/      # Django reader (GET operations)
│   ├── writer-service/writer/      # Django writer (CREATE/UPDATE/DELETE)
│   ├── shared/                     # Shared models and serializers
│   └── requirements.txt
├── infrastructure/terraform/
│   ├── envs/uat/                   # UAT environment config
│   └── modules/                    # Terraform modules
│       ├── secretsmanager.tf       # Secrets Manager + IRSA role
│       ├── eks-role.tf             # EKS roles + GitHub OIDC
│       ├── security-group.tf       # SG rules (incl. EKS → RDS)
│       └── ...
└── platform/
    ├── ingress/
    │   └── ingress.yaml            # ALB Ingress (API gateway)
    └── services/
        ├── reader-service/         # K8s manifests for reader
        │   ├── configmap.yaml
        │   ├── deployment.yaml
        │   ├── hpa.yaml
        │   ├── secret-provider.yaml
        │   └── service.yaml
        └── writer-service/         # K8s manifests for writer
            ├── configmap.yaml
            ├── deployment.yaml
            ├── hpa.yaml
            ├── secret-provider.yaml
            └── service.yaml
```

---

## Infrastructure (Terraform)

### Secrets Manager

**File:** `infrastructure/terraform/modules/secretsmanager.tf`

Database credentials are stored in AWS Secrets Manager — not as Kubernetes Secrets. The secret is created by Terraform and synced into pods at runtime via the Secrets Store CSI Driver.

**Secret name:** `django-api/uat/db-credentials`

**Stored values:**
| Key         | Source                                    |
|-------------|-------------------------------------------|
| DB_USER     | `var.db_user`                             |
| DB_PASSWORD | `var.db_password`                         |
| DB_HOST     | `aws_db_instance.database_instance.address` |
| DB_NAME     | `var.db_name`                             |
| DB_PORT     | `var.db_port`                             |

> **Important:** The `address` attribute is used instead of `endpoint` because `endpoint` includes the port suffix (e.g., `host:5432`), which causes Django to produce an invalid connection string.

**IRSA Role:** `django-api-uat-secrets-access-role` — allows pods with service accounts matching `*-service-sa` to call `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret`, scoped to the DB credentials secret only.

---

### GitHub Actions OIDC Role

**File:** `infrastructure/terraform/modules/eks-role.tf`

GitHub Actions authenticates to AWS using OIDC — no long-lived credentials.

**Resources created:**
- `aws_iam_openid_connect_provider.github` — GitHub OIDC provider (`token.actions.githubusercontent.com`)
- `aws_iam_role.github_actions_role` — IAM role `django-api-uat-github-actions-role` with trust scoped to `repo:effie-devops/Django-CQRS-microservices:*`

**Permissions (least privilege):**
- `ecr:GetAuthorizationToken` (all resources)
- ECR push actions (scoped to reader-service and writer-service repos)
- `eks:DescribeCluster`, `eks:ListClusters` (scoped to the cluster)

---

### EKS Access Entry

The GitHub Actions role needs kubectl access to the cluster. The EKS cluster auth mode was updated from `CONFIG_MAP` to `API_AND_CONFIG_MAP`, and an access entry was created:

```bash
# Switch auth mode (one-time)
aws eks update-cluster-config \
  --name django-api-uat-cluster \
  --region us-east-1 \
  --access-config authenticationMode=API_AND_CONFIG_MAP

# Create access entry for GitHub Actions role
aws eks create-access-entry \
  --cluster-name django-api-uat-cluster \
  --region us-east-1 \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:role/django-api-uat-github-actions-role \
  --type STANDARD

# Associate cluster admin policy
aws eks associate-access-policy \
  --cluster-name django-api-uat-cluster \
  --region us-east-1 \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:role/django-api-uat-github-actions-role \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

---

### Security Groups

**File:** `infrastructure/terraform/modules/security-group.tf`

The database security group was updated to allow inbound traffic from the EKS-managed cluster security group. EKS nodes use the auto-created `eks-cluster-sg-*` security group, not the custom `app_server_security_group` defined in Terraform.

```hcl
# database SG ingress now includes both:
security_groups = [
  aws_security_group.app_server_security_group.id,
  aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
]
```

---

## Platform (Kubernetes)

### Secrets Flow

Secrets are **never** stored as static Kubernetes Secrets. They are managed entirely by AWS Secrets Manager and synced into pods at runtime:

```
AWS Secrets Manager
  → Secrets Store CSI Driver (mounted as volume at /mnt/secrets-store)
    → secretObjects sync creates a K8s Secret automatically
      → env vars injected into containers via secretKeyRef
```

**Prerequisites installed on the cluster:**
1. **Secrets Store CSI Driver** (Helm chart with `syncSecret.enabled=true`)
2. **AWS Secrets Store CSI Driver Provider** (DaemonSet)

```bash
# Install CSI Driver
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true

# Install AWS Provider
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

---

### Reader Service

| Manifest              | Purpose                                                                 |
|-----------------------|-------------------------------------------------------------------------|
| `secret-provider.yaml`| SecretProviderClass — pulls from `django-api/uat/db-credentials`, syncs to K8s Secret `reader-service-db-secret` |
| `deployment.yaml`     | 2 replicas, ServiceAccount with IRSA, CSI volume mount, health probes, resource limits (100m-500m CPU, 256Mi-512Mi memory) |
| `configmap.yaml`      | Non-sensitive config: `DJANGO_SETTINGS_MODULE=reader.settings`          |
| `service.yaml`        | ClusterIP on port 80 → 8000                                            |
| `hpa.yaml`            | 2–6 replicas, scales at 70% CPU utilization                            |

---

### Writer Service

Same structure as reader service with `writer-service-*` naming.

---

### Ingress

**File:** `platform/ingress/ingress.yaml`

The AWS Load Balancer Controller acts as the API gateway, provisioning an internet-facing ALB with TLS termination.

**ALB Controller installation:**
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=django-api-uat-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<ALB_CONTROLLER_ROLE_ARN> \
  --set region=us-east-1 \
  --set vpcId=<VPC_ID>
```

**Routing rules:**
| Path       | Backend         |
|------------|-----------------|
| `/reader`  | reader-service  |
| `/writer`  | writer-service  |
| `/health`  | reader-service  |

**DNS:** Route 53 A record alias `apis.effiecancode.buzz` → ALB DNS name.

---

## CI/CD Pipeline

**File:** `.github/workflows/docker-image.yml`

### Triggers

1. **Push to `main`** — only when files change under `app/reader-service/` or `app/writer-service/`. Automatically detects which service changed.
2. **Manual dispatch** — choose `reader-service`, `writer-service`, or `both` from a dropdown.

### Pipeline Flow

```
detect-changes
  └─► build-and-deploy (matrix: reader-service, writer-service)
        ├─ Configure AWS credentials (OIDC)
        ├─ Login to ECR
        ├─ docker build + push (tagged with git SHA + latest)
        └─ kubectl set image + rollout status
```

**Key details:**
- Uses `fetch-depth: 2` to ensure `git diff HEAD~1` works
- Falls back to `git diff-tree` for first commits
- Build context is `app/` with `-f` pointing to the service-specific Dockerfile
- Images tagged with short SHA (`${GITHUB_SHA::7}`) and `latest`
- Deployment uses `kubectl set image` (pins exact SHA tag) instead of `rollout restart`

### Required GitHub Secrets

| Secret           | Value                                                    |
|------------------|----------------------------------------------------------|
| `AWS_ROLE_ARN`   | ARN of `django-api-uat-github-actions-role`              |
| `AWS_ACCOUNT_ID` | AWS account ID (used to construct ECR registry URL)      |

Set these in **Settings → Secrets and variables → Actions** in the GitHub repository.

---

## API Endpoints

Base URL: `https://apis.effiecancode.buzz`

### Reader Service (Query)

| Method | Endpoint                  | Description       |
|--------|---------------------------|-------------------|
| GET    | `/reader/books/`          | List all books    |
| GET    | `/reader/books/<id>/`     | Get a single book |
| GET    | `/reader/health/`         | Health check      |

### Writer Service (Command)

| Method | Endpoint                          | Description     |
|--------|-----------------------------------|-----------------|
| POST   | `/writer/books/create/`           | Create a book   |
| PUT    | `/writer/books/<id>/update/`      | Update a book   |
| DELETE | `/writer/books/<id>/delete/`      | Delete a book   |

### General

| Method | Endpoint    | Description              |
|--------|-------------|--------------------------|
| GET    | `/health/`  | Reader service health    |

---

## Troubleshooting

### Issues Resolved During Setup

#### 1. Secrets Manager `endpoint` vs `address`
**Problem:** `aws_db_instance.endpoint` includes the port (e.g., `host:5432`). Django appends its own port, resulting in `host:5432:5432`.
**Fix:** Use `aws_db_instance.address` in the Secrets Manager secret.

#### 2. GitHub Actions shallow clone
**Problem:** `git diff HEAD~1` fails with `unknown revision` because GitHub Actions defaults to `fetch-depth: 1`.
**Fix:** Set `fetch-depth: 2` on checkout, and fall back to `git diff-tree` for first commits.

#### 3. Docker build context
**Problem:** `requirements.txt` and `.env` live in `app/`, but Dockerfiles are in `app/<service>/`. Using the Dockerfile directory as build context caused `COPY requirements.txt .` to fail.
**Fix:** Set build context to `app/` and use `-f` to specify the Dockerfile path. Updated `COPY` instructions to use paths relative to `app/`.

#### 4. EKS authentication for GitHub Actions
**Problem:** The GitHub Actions IAM role could authenticate to AWS but got `the server has asked for the client to provide credentials` when running kubectl.
**Fix:** Switched EKS auth mode to `API_AND_CONFIG_MAP`, created an access entry for the role, and associated `AmazonEKSClusterAdminPolicy`.

#### 5. EKS nodes cannot reach RDS
**Problem:** The database security group only allowed inbound from `app_server_security_group`, but EKS nodes use the auto-created `eks-cluster-sg-*` security group.
**Fix:** Added `aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id` to the database security group ingress rule.

#### 6. Stale CSI-synced secrets
**Problem:** After updating the Secrets Manager value, pods still used the old cached value.
**Fix:** Deleted the synced K8s Secrets (`reader-service-db-secret`, `writer-service-db-secret`) and restarted the deployments so the CSI driver re-fetched from Secrets Manager.
