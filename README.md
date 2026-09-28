# Gambit — Production AWS Platform

A production-style cloud platform demonstrating the deployment, security, monitoring, and continuous delivery of containerized applications on AWS.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Infrastructure](#infrastructure)
- [Security](#security)
- [CI/CD Pipeline](#cicd-pipeline)
- [Observability](#observability)
- [Backup & Disaster Recovery](#backup--disaster-recovery)
- [Production Validation](#production-validation)
- [Current Limitations](#current-limitations)
- [Repository Structure](#repository-structure)
- [Goals Demonstrated](#goals-demonstrated)

---

## Quick Start

### Prerequisites
- Terraform
- Docker
- AWS CLI configured
- GitHub account (for OIDC authentication)

### Deployment
```bash
# Initialize Terraform
cd terraform
terraform init

# Plan and apply infrastructure
terraform plan
terraform apply

# Deploy via CI/CD
git push  # Triggers GitHub Actions pipeline
```

### Local Development
```bash
docker-compose up
```

---

## Architecture

```
                     Internet
                        |
                        v
             +----------------------+
             | Application Load     |
             | Balancer (ALB)       |
             | HTTP :80             |
             +----------+-----------+
                        |
          +-------------+-------------+
          |                           |
          v                           v
  +---------------+           +---------------+
  | Frontend ECS  |           | Backend ECS   |
  | Fargate       |           | Fargate       |
  | Nginx :80     |           | FastAPI :8000 |
  +---------------+           +-------+-------+
                                      |
                                      v
                              +---------------+
                              | PostgreSQL RDS|
                              | Private       |
                              | Port 5432     |
                              +---------------+

Private ECS workloads use a NAT Gateway for outbound internet access.
```

### Components

**Frontend**
- React + Vite
- Nginx reverse proxy
- Security headers configured
- Non-root container execution

**Backend**
- FastAPI
- SQLAlchemy ORM
- PostgreSQL database
- Alembic migrations
- Read-only API surface (currently)
- Production API documentation disabled
- CORS restricted to production frontend

**ALB Routing**
| Path | Destination |
|------|-------------|
| `/health` | Backend |
| `/info` | Backend |
| `/api/services` | Backend |
| `/api/deployments` | Backend |
| Other paths | Frontend |

---

## Infrastructure

Deployed in **eu-west-2** (London) using Terraform.

### Network
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 2 (eu-west-2a, eu-west-2b)
- **Private Subnets**: 3 (eu-west-2a, eu-west-2b, eu-west-2c)
- **Internet Gateway**: For public subnet traffic
- **NAT Gateway**: For private subnet outbound access
- **Internet-facing ALB**: HTTP :80

### Compute
- **Amazon ECS on Fargate**: Serverless container orchestration
- **Separate frontend and backend services**: Independent scaling

### Database
- **Amazon RDS PostgreSQL**: Private, encrypted
- **Port**: 5432 (restricted to ECS security group)
- **Not publicly accessible**

### Managed Services
- **AWS Secrets Manager**: RDS credentials and sensitive data
- **CloudWatch Logs**: 14-day retention
- **CloudWatch Alarms**: Service health monitoring
- **Amazon SNS**: Email alerting

---

## Security

Gambit implements **layered network, IAM, application, and container security controls**.

### Network Security
- ✅ ECS tasks have **no public IP addresses**
- ✅ RDS **not publicly accessible**
- ✅ ECS ingress **restricted to ALB security group**
- ✅ RDS access **restricted to ECS security group**
- ✅ Private subnet outbound traffic through **NAT Gateway**

### IAM & Authentication
- ✅ **GitHub OIDC**: OpenID Connect federation instead of long-lived AWS keys
- ✅ **Least-privilege design**: Separate execution and deployment roles
- ✅ **Secrets Manager**: Secure credential retrieval

**Deployment Role Permissions**:
- ECR image publishing
- ECS service deployment
- Database migration execution
- CloudWatch log reads
- ECS task definition registration

**ECS Execution Role Permissions**:
- Retrieve RDS secrets from Secrets Manager
- Write logs to CloudWatch

### Container Security

CI enforces:
- ✅ Non-root containers
- ✅ Secret detection (Gitleaks)
- ✅ Docker image scanning (Trivy)
- ✅ Dependency auditing
- ✅ No privileged containers
- ✅ Controlled Linux capabilities

See `security/security-policy.md` for detailed policy.

---

## CI/CD Pipeline

**GitHub Actions** provides automated production delivery.

### Workflow Stages

```
Git Push
  ├── Frontend CI tests
  ├── Backend CI tests
  ├── Secret Detection (Gitleaks)
  ├── Docker Build + Security Scan (Trivy)
  ├── Integration Tests
  ├── Push Images to Amazon ECR
  ├── Register ECS Task Definitions
  ├── Run Alembic Migrations
  ├── Update ECS Services
  ├── Wait for Deployment Stability
  └── Verify ECS Services
```

### Key Features
- **No permanent AWS keys**: Uses GitHub OIDC federation
- **Automated testing**: Frontend, backend, and integration tests
- **Security scanning**: Gitleaks and Trivy on every build
- **Database migrations**: Executed before service updates
- **Deployment validation**: Waits for service stability before completing

### Database Migrations

Schema changes use **Alembic**. Production deployments execute:

```bash
alembic upgrade head
```

as an ECS task before updating services.

---

## Observability

### Centralized Logging
- **CloudWatch Logs**: All ECS container logs
- **14-day retention**: Automatic cleanup
- **ECS Container Insights**: Performance monitoring

### Alarms & Alerting
Monitored metrics with SNS email alerts:

**Backend**
- CPU utilization
- Memory utilization
- 5xx error rate
- Task availability
- Target health

**Frontend**
- CPU utilization
- Memory utilization
- 5xx error rate
- Task availability
- Target health

---

## Backup & Disaster Recovery

### RDS Configuration
- ✅ **Point-in-time recovery**: Restore to any point within retention period
- ✅ **Automated backups**: Daily snapshots
- ✅ **Manual snapshots**: On-demand backup capability
- ✅ **Deletion protection**: Prevents accidental deletion

### Current Limitations
- ⚠️ Backup retention: **1 day** (should be extended to 7+ days)
- ⚠️ **RDS Multi-AZ disabled** (should be enabled for HA)
- ⚠️ **No production restore drill executed**

### Recommendations
1. Increase backup retention to 7-30 days
2. Enable RDS Multi-AZ for high availability
3. Execute quarterly restore drills
4. Document RTO/RPO requirements

---

## Production Validation

The final production validation confirmed:

- ✅ ECS frontend service healthy
- ✅ ECS backend service healthy
- ✅ ALB frontend target healthy
- ✅ ALB backend target healthy
- ✅ RDS available and private
- ✅ Production CloudWatch alarms in OK state
- ✅ SNS email subscription confirmed
- ✅ Application paths returning HTTP 200
- ✅ Production FastAPI documentation disabled
- ✅ CI/CD pipeline completing successfully
- ✅ Integration tests passing
- ✅ Latest ECS deployment completing successfully

---

## Current Limitations

The following are **intentionally documented** production limitations:

| Limitation | Impact | Status |
|------------|--------|--------|
| HTTP instead of HTTPS | Unencrypted traffic | Use CloudFront + ACM for production |
| RDS Multi-AZ disabled | Single point of failure | Enable for production HA |
| 1-day backup retention | Limited recovery window | Increase to 7+ days |
| No restore drill executed | Untested recovery process | Schedule quarterly drills |
| ECR image scanning disabled | Vulnerability detection delayed | Enable on-push scanning |
| ECR mutable tags | Risk of tag overwrite | Use immutable tags in prod |
| ECS IAM wildcards | Over-permissive roles | Scope to specific resources |
| Terraform not authoritative for active ECS revisions | GitHub Actions manages application deployment revisions | Keep infrastructure and application deployment responsibilities documented separately |

---

## Repository Structure

```
Gambit/
├── app/
│   ├── backend/
│   │   ├── main.py
│   │   ├── requirements.txt
│   │   └── alembic/
│   └── frontend/
│       ├── src/
│       ├── package.json
│       └── vite.config.js
├── security/
│   └── security-policy.md
├── terraform/
│   ├── alb.tf
│   ├── cloudwatch.tf
│   ├── cloudwatch_alarms.tf
│   ├── ecs.tf
│   ├── iam.tf
│   ├── nat.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── rds.tf
│   ├── security_groups.tf
│   ├── sns.tf
│   ├── variables.tf
│   ├── vpc.tf
│   └── .terraform.lock.hcl
├── .github/
│   └── workflows/
│       └── ci.yml
├── docker-compose.yml
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Goals Demonstrated

Gambit demonstrates practical production experience with:

### Cloud & Infrastructure
- ✅ AWS cloud architecture and best practices
- ✅ Terraform Infrastructure as Code
- ✅ VPC design with public/private subnets
- ✅ Application Load Balancing and routing

### Containerization & Orchestration
- ✅ Docker containerization
- ✅ Amazon ECS Fargate (serverless containers)
- ✅ Amazon ECR (container registry)
- ✅ Multi-service deployments

### Database & Persistence
- ✅ Amazon RDS PostgreSQL
- ✅ Database migrations (Alembic)
- ✅ Backup and disaster recovery patterns

### Security & Compliance
- ✅ IAM least-privilege design
- ✅ GitHub OIDC federation
- ✅ Container security scanning
- ✅ Dependency vulnerability auditing
- ✅ Network security controls

### Operations & Monitoring
- ✅ CI/CD automation (GitHub Actions)
- ✅ CloudWatch monitoring and alarms
- ✅ SNS alerting
- ✅ Centralized logging
- ✅ Production validation and runbooks

---

## Support & Documentation

For detailed information, see:
- `security/security-policy.md` — Security policies and controls
- `terraform/` — Infrastructure code and configuration
- `.github/workflows/ci.yml` — CI/CD pipeline definition

---
