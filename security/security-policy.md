# Gambit Container Security Policy

## Purpose

This document defines the security controls and minimum security requirements for Gambit's containerized application platform.

The policy applies to:

* Application source code
* Docker images
* Python and Node.js dependencies
* Container runtime configuration
* Secrets
* CI/CD workflows
* AWS ECS Fargate workloads

---

## Vulnerability Thresholds

CI must fail when any of the following are detected:

* CRITICAL vulnerabilities
* HIGH vulnerabilities
* Confirmed leaked secrets
* Critical container security misconfigurations

MEDIUM and LOW vulnerabilities are reported but do not currently block CI.

Security findings that do not meet the blocking threshold should still be reviewed and addressed according to their risk.

---

## Container Security

Application containers must:

* Run as a non-root user.
* Avoid unnecessary Linux capabilities.
* Not run in privileged mode.
* Not embed secrets in images.
* Use controlled and version-pinned base images where practical.
* Expose only the ports required by the application.
* Use a minimal base image where practical.
* Be scanned for known vulnerabilities before deployment.

The production ECS workloads run on AWS Fargate and do not receive public IP addresses.

---

## Docker Image Security

Gambit uses Amazon ECR for application container images.

The production repositories are:

* `gambit-frontend`
* `gambit-backend`

Container images are scanned during CI using Trivy.

Images must not contain:

* Passwords
* API keys
* Access tokens
* Private keys
* Database credentials
* AWS credentials
* Other application secrets

ECR image tags are currently mutable and ECR push-time scanning is disabled. These are documented architectural limitations and are candidates for future hardening.

---

## Dependency Security

### Backend

Python dependencies must be explicitly version controlled in:

```text
app/backend/requirements.txt
```

Dependency vulnerabilities are checked during CI.

Known HIGH and CRITICAL vulnerabilities must be investigated before release.

### Frontend

The frontend dependency lock file must remain committed:

```text
app/frontend/package-lock.json
```

NPM dependency auditing is performed during CI.

HIGH and CRITICAL dependency vulnerabilities should block the release pipeline unless an explicit risk decision has been documented.

---

## Secret Security

Secrets must never be committed to Git or embedded in Docker images.

Examples include:

* Passwords
* API keys
* Access tokens
* Private keys
* Database credentials
* Cloud credentials

Production database credentials are stored in AWS Secrets Manager.

ECS retrieves the required database secrets through the configured ECS execution-role permissions rather than storing credentials directly in the application source code or container image.

Local development secrets must be kept outside version control.

Environment files containing secrets, such as `.env`, must remain excluded through `.gitignore`.

---

## Source Code and Repository Security

The repository must not contain committed credentials or sensitive configuration.

Gitleaks is used in CI to detect accidentally committed secrets.

Security-sensitive changes should be reviewed before being merged into the production branch.

---

## AWS and Runtime Security

Gambit's production workloads use AWS ECS Fargate.

Security boundaries include:

### Application Load Balancer

The public Application Load Balancer is the internet-facing entry point.

The ALB security group controls public inbound traffic.

### ECS

ECS tasks:

* Do not have public IP addresses.
* Accept application traffic only from the ALB security group.
* Run using the configured ECS execution role.
* Run as non-root application containers.
* Do not run in privileged mode.

### RDS

The PostgreSQL database:

* Is not publicly accessible.
* Accepts database traffic only from the ECS security group.
* Uses encrypted storage.
* Uses deletion protection.
* Stores credentials in AWS Secrets Manager.

---

## CI/CD Security Controls

The CI/CD pipeline performs security checks before production deployment.

Current controls include:

* Gitleaks secret detection
* Trivy container image scanning
* Python dependency auditing
* NPM dependency auditing
* Docker security checks
* Container runtime security checks
* Integration testing

AWS deployment authentication uses GitHub Actions OIDC federation rather than long-lived AWS access keys stored in GitHub secrets.

The GitHub Actions deployment role is scoped to the Gambit deployment requirements.

---

## IAM Security

AWS IAM permissions should follow least-privilege principles.

Separate IAM roles are used for:

* GitHub Actions deployment
* ECS task execution

Permissions should be restricted to the resources and actions required by each role where AWS supports resource-level restrictions.

IAM policies using wildcard resources are reviewed as part of ongoing security hardening.

---

## Network Security

The Gambit network uses separate public and private subnets.

Public resources include:

* Application Load Balancer
* NAT Gateway

Private resources include:

* ECS application workloads
* RDS PostgreSQL

The application and database workloads do not receive direct public internet ingress.

Security groups enforce service-to-service communication:

```text
Internet
   |
   v
ALB :80
   |
   v
ECS Frontend :80 / Backend :8000
   |
   v
RDS PostgreSQL :5432
```

---

## Security Logging and Monitoring

CloudWatch collects ECS application and infrastructure logs.

Security-relevant operational conditions are monitored through CloudWatch alarms.

SNS is used to deliver configured production alerts.

Current alerting covers conditions including:

* High CPU utilization
* High memory utilization
* No running ECS tasks
* HTTP 5xx responses
* Unhealthy ALB targets

---

## Vulnerability Exceptions

A vulnerability may be temporarily accepted when:

1. There is no practical immediate remediation.
2. The vulnerability does not create an unacceptable production risk.
3. The finding is documented.
4. A remediation plan is identified.

Exceptions should include:

* Vulnerability identifier
* Affected component
* Risk assessment
* Reason for temporary acceptance
* Planned remediation
* Review date

Critical vulnerabilities and confirmed secret exposure should not be routinely accepted without explicit security review.

---

## Security Limitations

The current production architecture has several known security-related limitations:

* ALB currently exposes HTTP on port 80; HTTPS/TLS is planned.
* ECR push-time vulnerability scanning is currently disabled.
* ECR image tags are currently mutable.
* IAM hardening remains an ongoing activity.
* RDS Multi-AZ is currently disabled.
* Backup retention is currently limited to one day.

These limitations are documented in the project's production architecture and README documentation.

---

## Security Review

The security policy should be reviewed when significant changes are made to:

* AWS infrastructure
* IAM permissions
* Container images
* CI/CD workflows
* Secret-management mechanisms
* Network architecture
* Database architecture

Security controls should be updated whenever the production architecture changes.

---

## Related Documentation

* `README.md`
* `docs/architecture.md`
* `security/security-policy.md`
* `.github/workflows/ci.yml`

**Policy Version:** 1.0
**Environment:** Production
**Platform:** AWS ECS Fargate
