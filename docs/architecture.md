# Gambit — Production AWS Architecture

## Overview

Gambit is a production-style containerized application platform deployed on AWS. The platform separates frontend and backend workloads into independent Amazon ECS Fargate services. An internet-facing Application Load Balancer provides the public entry point and routes requests to the appropriate service.

The backend communicates with a private Amazon RDS PostgreSQL database.

**Key Technologies:**
- Infrastructure: Terraform
- CI/CD: GitHub Actions with AWS OIDC federation
- Container Orchestration: Amazon ECS Fargate
- Database: Amazon RDS PostgreSQL
- Observability: CloudWatch, SNS

---

## Table of Contents

- [AWS Region & Availability](#aws-region--availability)
- [High-Level Architecture](#high-level-architecture)
- [Network Architecture](#network-architecture)
- [Traffic Flow](#traffic-flow)
- [Application Components](#application-components)
- [Security Boundaries](#security-boundaries)
- [Compute Architecture](#compute-architecture)
- [Database Architecture](#database-architecture)
- [Secrets Management](#secrets-management)
- [Observability](#observability)
- [CI/CD Pipeline](#cicd-pipeline)
- [Infrastructure as Code](#infrastructure-as-code)
- [Database Migrations](#database-migrations)
- [Backup & Disaster Recovery](#backup--disaster-recovery)
- [Architectural Limitations](#architectural-limitations)
- [Design Principles](#design-principles)

---

## AWS Region & Availability

**Production Environment:**
- **Region:** `eu-west-2` (London)
- **Availability Zones:** `eu-west-2a`, `eu-west-2b`, `eu-west-2c`

The VPC spans three Availability Zones, providing subnet-level distribution
for the architecture. Application and database high availability remain
limited by the current ECS desired count and disabled RDS Multi-AZ configuration.

---

## High-Level Architecture

```
                          Internet
                              |
                              v
                +---------------------------+
                | Application Load Balancer |
                | HTTP :80                  |
                +-------+---------+---------+
                        |
        +---------------+---------------+
        |                               |
        v                               v
+-------------------+         +-------------------+
| Frontend ECS      |         | Backend ECS       |
| Fargate           |         | Fargate           |
| Nginx :80         |         | FastAPI :8000     |
+-------------------+         +---------+---------+
                                        |
                                        v
                              +-------------------+
                              | PostgreSQL RDS    |
                              | Private           |
                              | Port 5432         |
                              +-------------------+

Private ECS workloads route outbound traffic through NAT Gateway
```

---

## Network Architecture

### VPC Design

| Component | Value |
|-----------|-------|
| **VPC CIDR** | `10.0.0.0/16` |
| **Region** | `eu-west-2` |
| **Availability Zones** | 3 (a, b, c) |

### Public Subnets

Two public subnets provide inbound access points:

| AZ | Purpose |
|---|---------|
| `eu-west-2a` | ALB, NAT Gateway |
| `eu-west-2b` | ALB (redundancy) |

**Public Subnet Features:**
- ✅ Direct internet connectivity via Internet Gateway
- ✅ Application Load Balancer
- ✅ NAT Gateway for private subnet outbound access

### Private Subnets

Three private subnets are configured across:

| AZ | Purpose |
|---|---|
| `eu-west-2a` | ECS workloads |
| `eu-west-2b` | ECS workloads |
| `eu-west-2c` | RDS subnet-group coverage |

RDS Multi-AZ is currently disabled, so the presence of multiple subnets does
not represent an active RDS standby or replica deployment.

**Private Subnet Features:**
- ✅ No direct internet access
- ✅ Outbound access through NAT Gateway
- ✅ Application isolation
- ✅ Database isolation

### Routing

**Public Subnets**
```
Route: 0.0.0.0/0 → Internet Gateway
```

**Private Subnets**
```
Route: 0.0.0.0/0 → NAT Gateway (for outbound only)
```

---

## Traffic Flow

### Incoming Application Traffic

The Application Load Balancer routes requests based on path:

```
Internet Request
    ↓
Application Load Balancer
    ↓
    ├─ /health          → Backend
    ├─ /info            → Backend
    ├─ /api/services    → Backend
    ├─ /api/deployments → Backend
    └─ /* (all others)  → Frontend
```

### Protocol & Port

| Component | Protocol | Port |
|-----------|----------|------|
| **ALB → Internet** | HTTP | 80 |
| **Frontend (Nginx)** | HTTP | 80 |
| **Backend (FastAPI)** | HTTP | 8000 |
| **RDS (PostgreSQL)** | TCP | 5432 |

---

## Application Components

### Frontend

**Stack:**
- React (UI framework)
- Vite (build tool)
- Nginx (reverse proxy, static file serving)

**Deployment:**
- Amazon ECS Fargate
- Listens on port 80
- Non-root container execution
- Security headers configured at Nginx layer

**Features:**
- Static asset serving
- Reverse proxy to backend via ALB
- Security headers (CSP, X-Frame-Options, etc.)

### Backend

**Stack:**
- FastAPI (Python web framework)
- SQLAlchemy (ORM)
- Alembic (database migrations)
- PostgreSQL (database)

**Deployment:**
- Amazon ECS Fargate
- Listens on port 8000
- Non-root container execution

**Features:**
- RESTful API endpoints
- Read-only surface area (currently)
- CORS restricted to production frontend origin
- Production API documentation disabled
- Automated schema migrations on deploy

### Database

**Configuration:**
- **Engine:** PostgreSQL
- **Accessibility:** Private (not publicly accessible)
- **Network Location:** Private subnet
- **Port:** 5432
- **Encryption:** Storage encryption enabled
- **Credentials:** AWS Secrets Manager

---

## Security Boundaries

### Security Group Architecture

The architecture uses security groups to create network isolation:

```
Internet
    ↓
┌─────────────────────────────┐
│ ALB Security Group          │
│ • Inbound: 0.0.0.0/0 :80    │
│ • Outbound: All             │
└────────────┬────────────────┘
             ↓
┌─────────────────────────────┐
│ ECS Security Group          │
│ • Inbound: ALB SG :80       │
│ • Outbound: All (NAT)       │
│ • No public IPs             │
└────────────┬────────────────┘
             ↓
┌─────────────────────────────┐
│ RDS Security Group          │
│ • Inbound: ECS SG :5432     │
│ • Outbound: None            │
│ • Private only              │
└─────────────────────────────┘
```

### Trust Model

| Level | Boundary | Control |
|-------|----------|---------|
| **1** | Internet → ALB | Security Group rules |
| **2** | ALB → ECS | Security Group rules |
| **3** | ECS → RDS | Security Group rules |

**Key Properties:**
- ✅ ECS tasks have **no public IP addresses**
- ✅ RDS is **not publicly accessible**
- ✅ All communication flows through security groups
- ✅ Implicit deny for all non-matching traffic

---

## Compute Architecture

### ECS Cluster

**Cluster Name:** `gambit-production`

**Configuration:**
- **Launch Type:** AWS Fargate (serverless)
- **No EC2 instances:** Fully managed by AWS
- **Auto-scaling:** Configured per service

### Services

#### Frontend Service

| Property | Value |
|----------|-------|
| **Service Name** | `gambit-frontend` |
| **Task Definition** | `gambit-frontend:*` |
| **Container Port** | 80 |
| **Desired Count** | 1+ (auto-scalable) |
| **Health Check** | ALB target health |

#### Backend Service

| Property | Value |
|----------|-------|
| **Service Name** | `gambit-backend` |
| **Task Definition** | `gambit-backend:*` |
| **Container Port** | 8000 |
| **Desired Count** | 1+ (auto-scalable) |
| **Health Check** | ALB target health |

### Container Registry

**Amazon ECR Repositories:**

| Repository | Purpose |
|------------|---------|
| `gambit-frontend` | React + Nginx images |
| `gambit-backend` | FastAPI images |

**Configuration:**
- ⚠️ Image scanning on push: **Disabled** (future improvement)
- ⚠️ Tag mutability: **Enabled** (should use immutable in prod)
- ✅ Encryption: **Enabled**

---

## Database Architecture

### RDS PostgreSQL

**Configuration:**

| Setting | Value |
|---------|-------|
| **Engine** | PostgreSQL 16.15 |
| **Instance Class** | db.t4g.micro |
| **Encryption** | ✅ Enabled |
| **Publicly Accessible** | ❌ No |
| **Multi-AZ** | ❌ Disabled |
| **Deletion Protection** | ✅ Enabled |

### Backup Configuration

| Feature | Status |
|---------|--------|
| **Automated Backups** | ✅ Enabled |
| **Backup Retention** | 1 day |
| **Point-in-Time Recovery** | ✅ Enabled |
| **Manual Snapshots** | ✅ Enabled |
| **Snapshot Encryption** | ✅ Enabled |

### High Availability Considerations

**Current State:**
- Single-AZ deployment
- RDS Multi-AZ: **Disabled**

**Limitations:**
- ⚠️ No automatic failover
- ⚠️ No standby replica
- ⚠️ Manual backup restoration required

**Recommendations:**
1. Enable Multi-AZ for production HA
2. Increase backup retention to 7-30 days
3. Execute quarterly restore drills
4. Monitor failover procedures

---

## Secrets Management

### AWS Secrets Manager

**Sensitive Data Stored:**
- RDS database password
- Database connection strings
- API keys (if applicable)

**Access Control:**
- ECS execution role can retrieve secrets
- Secrets are **not** stored in source code
- Secrets are **not** committed to Git

### Task Definition Integration

```
ECS Task Definition
    ↓
Container Environment Variables
    ↓
Execution Role (Secrets Manager permission)
    ↓
AWS Secrets Manager
    ↓
Database Credentials
```

**Flow:**
1. ECS task definition references secret ARN
2. ECS execution role has `secretsmanager:GetSecretValue` permission
3. Container receives secret value at runtime
4. Application uses secret for database connection

---

## Observability

### CloudWatch Logs

**Log Configuration:**
- **Log Group:** `/ecs/gambit-production`
- **Retention:** 14 days
- **Encryption:** CloudWatch Logs encryption (optional)

**What's Logged:**
- Frontend (Nginx) access logs
- Frontend error logs
- Backend (FastAPI) application logs
- Backend error logs

### Container Insights

**ECS Container Insights Metrics:**

**Frontend Metrics:**
- CPU utilization
- Memory utilization
- Network in/out
- Running task count

**Backend Metrics:**
- CPU utilization
- Memory utilization
- Network in/out
- Running task count

### CloudWatch Alarms

**Monitored Metrics with Alerts:**

| Service | Metric | Threshold | Action |
|---------|--------|-----------|--------|
| **Backend** | CPU utilization | 80% | SNS alert |
| **Backend** | Memory utilization | 80% | SNS alert |
| **Backend** | 5xx errors | >5/min | SNS alert |
| **Backend** | Task availability | <1 task | SNS alert |
| **Backend** | Target health | Unhealthy | SNS alert |
| **Frontend** | CPU utilization | 80% | SNS alert |
| **Frontend** | Memory utilization | 80% | SNS alert |
| **Frontend** | 5xx errors | >5/min | SNS alert |
| **Frontend** | Task availability | <1 task | SNS alert |
| **Frontend** | Target health | Unhealthy | SNS alert |

### SNS Alerting

**Configuration:**
- SNS topic: `gambit-production-alerts`
- Subscribers: Production team email
- Protocol: Email
- Status: ✅ Confirmed

---

## CI/CD Pipeline

### Deployment Flow

```
Developer Push
    ↓
GitHub Repository
    ↓
GitHub Actions Triggered
    ├─ Lint & Test (Frontend)
    ├─ Lint & Test (Backend)
    ├─ Secret Detection (Gitleaks)
    ├─ Docker Build (Frontend)
    ├─ Docker Build (Backend)
    ├─ Security Scan (Trivy)
    ├─ Integration Tests
    ├─ Push to ECR
    ├─ Register Task Definition
    ├─ Run Alembic Migrations
    ├─ Update ECS Services
    ├─ Wait for Stability
    └─ Verify Deployment
    ↓
AWS Production
```

### Authentication

**GitHub OIDC Federation:**
- ✅ No long-lived AWS access keys
- ✅ Token-based authentication
- ✅ Time-limited credentials
- ✅ Enhanced security posture

**IAM Role for GitHub Actions:**
- Permissions for ECR push
- Permissions for ECS deployment
- Permissions for Alembic migrations
- Permissions for CloudWatch logs

### Stages Explained

| Stage | Purpose | Duration |
|-------|---------|----------|
| **Tests** | Run unit/integration tests | ~5 min |
| **Gitleaks** | Detect hardcoded secrets | ~2 min |
| **Docker Build** | Build container images | ~10 min |
| **Trivy Scan** | Security vulnerability scan | ~3 min |
| **Integration Tests** | End-to-end tests | ~10 min |
| **ECR Push** | Push images to registry | ~2 min |
| **Task Definition** | Register new revision | ~1 min |
| **Migrations** | Run Alembic upgrade head | ~5 min |
| **ECS Update** | Deploy to production | ~2 min |
| **Stability Wait** | Wait for healthy tasks | ~5 min |
| **Verification** | Verify service health | ~2 min |

---

## Infrastructure as Code

### Terraform Configuration

**Managed Resources:**

```
terraform/
├── alb.tf                    # Application Load Balancer
├── cloudwatch.tf             # Logging configuration
├── cloudwatch_alarms.tf      # Monitoring & alerts
├── ecs.tf                    # ECS cluster & services
├── iam.tf                    # IAM roles & policies
├── nat.tf                    # NAT Gateway
├── outputs.tf                # Output values
├── providers.tf              # AWS provider config
├── rds.tf                    # RDS PostgreSQL
├── security_groups.tf        # Security groups
├── sns.tf                    # SNS topics
├── variables.tf              # Variable definitions
├── vpc.tf                    # VPC & subnets
└── .terraform.lock.hcl       # Provider lock file
```

### State Management

**Configuration:**
- ✅ Terraform state stored remotely (S3 or similar)
- ✅ State encryption enabled
- ✅ State lock implemented
- ✅ `.tfstate` excluded from Git

**Best Practices:**
- Never commit state files to Git
- Use remote backend with encryption
- Implement access controls
- Regular backups of state

### Deployment Separation

**Terraform Manages:**
- Infrastructure (VPC, subnets, security groups, ALB, RDS)
- IAM roles and policies
- CloudWatch logs and alarms
- SNS topics

**GitHub Actions Manages:**
- Active ECS task-definition revisions
- Current ECS service deployments
- Production application versions

**Why Separation?**
- Prevents manual state drift
- Allows fast application deployments
- Infrastructure stability
- Clear responsibility boundaries

---

## Database Migrations

### Alembic Integration

**Migration Tool:** Alembic (SQLAlchemy migration framework)

**Migration Location:** `app/backend/alembic/`

### Deployment Process

**Pre-deployment Migration:**

```
GitHub Actions Triggers
    ↓
ECR Images Built & Pushed
    ↓
ECS Task Definition Registered
    ↓
Alembic Migration Task Launched
    ↓
alembic upgrade head
    ↓
Schema Updated (if changes)
    ↓
ECS Services Updated
    ↓
New Code Running on Updated Schema
```

**Key Properties:**
- ✅ Migrations run **before** service update
- ✅ Automatic schema version management
- ✅ Reversible migrations
- ✅ Version tracking in `alembic_version` table

### Creating Migrations

```bash
# Detect schema changes
alembic revision --autogenerate -m "Add user table"

# Review generated migration
vim app/backend/alembic/versions/xxx_add_user_table.py

# Deploy (automatic via CI)
git push
```

---

## Backup & Disaster Recovery

### RDS Backup Strategy

**Automated Backups:**
- ✅ Daily snapshots
- ✅ Point-in-time recovery
- ⚠️ 1-day retention (should be 7+ days)

**Manual Snapshots:**
- ✅ On-demand capability
- Pre-deployment snapshots recommended
- Labeled with timestamp/description

**Deletion Protection:**
- ✅ Enabled (prevents accidental deletion)
- Requires explicit IAM permission to disable

### Recovery Capabilities

| Scenario | RTO | RPO | Method |
|----------|-----|-----|--------|
| **Single-point failure** | N/A | N/A | Not applicable (single-AZ) |
| **Data corruption** | 2-4 hours | <1 hour | Point-in-time restore |
| **Accidental delete** | 2-4 hours | <1 hour | Snapshot restore |
| **Region failure** | Not available | Not available | Manual cross-region restore |

### Current Limitations

| Limitation | Impact | Recommendation |
|-----------|--------|-----------------|
| 1-day backup retention | Limited recovery window | Increase to 7-30 days |
| Single-AZ deployment | No automatic failover | Enable Multi-AZ |
| No restore drill | Untested recovery | Schedule quarterly drills |
| Manual cross-region | Extended RTO | Implement automated replication |

### Disaster Recovery Recommendations

**Immediate (Week 1):**
1. Increase backup retention to 7 days
2. Document restore procedures
3. Schedule first restore drill

**Short-term (Month 1):**
1. Enable RDS Multi-AZ
2. Execute quarterly restore drills
3. Automate backup verification

**Medium-term (Quarter 1):**
1. Implement cross-region backup replication
2. Document full disaster recovery runbook
3. Test cross-region failover

---

## Architectural Limitations

### Documented Production Limitations

| Area | Current State | Future Improvement | Priority |
|------|---------------|-------------------|----------|
| **Transport Security** | HTTP :80 | HTTPS with CloudFront + ACM | High |
| **Database HA** | Single-AZ | Enable Multi-AZ | High |
| **Backup Retention** | 1 day | 7-30 days | Medium |
| **DR Testing** | Not performed | Quarterly drills | Medium |
| **ECR Scanning** | Disabled | Enable on-push | Low |
| **ECR Tags** | Mutable | Immutable tags | Low |
| **ECS Replicas** | Desired count: 1 | Desired count: 2+ | Medium |
| **Infrastructure Authority** | GitHub Actions | Terraform only | Low |

### Rationale

These limitations are **intentionally documented** to:
- ✅ Acknowledge production gaps
- ✅ Plan improvements
- ✅ Prioritize hardening efforts
- ✅ Communicate risk to stakeholders

---

## Design Principles

Gambit follows these core architectural principles:

### 1. Infrastructure as Code
- ✅ All AWS infrastructure defined in Terraform
- ✅ Version-controlled
- ✅ Reproducible deployments
- ✅ No manual resource creation

### 2. Managed AWS Services
- ✅ ECS Fargate (no EC2 management)
- ✅ RDS (no database administration)
- ✅ ECR (managed container registry)
- ✅ CloudWatch (managed logging)
- ✅ Secrets Manager (managed secrets)
- ✅ SNS (managed alerting)

### 3. Network Isolation
- ✅ Private subnets for workloads
- ✅ Security group-based access control
- ✅ No direct internet access to application
- ✅ NAT Gateway for outbound traffic

### 4. Least-Privilege IAM
- ✅ Separate deployment and execution roles
- ✅ Specific permissions per role
- ✅ Resource-specific policies
- ✅ Regular access reviews

### 5. Federated Authentication
- ✅ GitHub OIDC federation
- ✅ No long-lived AWS credentials
- ✅ Time-limited tokens
- ✅ Enhanced audit trail

### 6. Automated Delivery
- ✅ Continuous integration
- ✅ Automated testing
- ✅ Security scanning
- ✅ Automated database migrations
- ✅ Continuous deployment

### 7. Operational Visibility
- ✅ Centralized logging
- ✅ Metrics and monitoring
- ✅ Automated alarms
- ✅ Email notifications
- ✅ Production dashboards

### 8. Explicit Limitations
- ✅ Known gaps documented
- ✅ Future improvements planned
- ✅ Risks communicated
- ✅ Stakeholders informed

---

## Related Documentation

- **README.md** — Project overview and quick start
- **security/security-policy.md** — Security controls and compliance
- **.github/workflows/ci.yml** — CI/CD pipeline implementation
- **terraform/** — Infrastructure as Code configuration

---
**Architecture Version:** 1.0