# Gambit CI/CD Runbook

## Purpose

This runbook documents the Gambit continuous integration and continuous delivery pipeline implemented with GitHub Actions.

The pipeline validates application code, scans secrets and container images, runs integration tests, publishes production images to Amazon ECR, runs database migrations, and deploys the application to Amazon ECS Fargate.

---

## Pipeline Overview

The production delivery path is:

```text
Git Push
   |
   v
Frontend CI ───────┐
                   |
Backend CI ────────┤
                   |
Secret Detection ──┘
          |
          v
Docker Build & Security Scan
          |
          v
Integration Tests
          |
          v
Amazon ECR
          |
          v
ECS Task Definition
          |
          v
Database Migration
          |
          v
ECS Service Update
          |
          v
ECS Stability Check
          |
          v
Production Verification
```

---

## Repository Branches

The workflow is configured for:

* `develop`
* `main`

The CI workflow runs for:

```text
Push:
  develop
  main

Pull Request:
  develop
  main
```

Production image publishing and ECS deployment currently occur only when code is pushed directly or merged into:

```text
develop
```

The deployment condition is:

```text
github.event_name == 'push'
AND
github.ref == 'refs/heads/develop'
```

---

## GitHub Actions Workflow

Workflow file:

```text
.github/workflows/ci.yml
```

Workflow name:

```text
Gambit CI
```

GitHub Actions permissions include:

```text
contents: read
id-token: write
```

The `id-token: write` permission enables GitHub Actions OIDC federation with AWS.

---

# Continuous Integration

## 1. Frontend CI

The frontend job runs on:

```text
ubuntu-latest
```

Node.js version:

```text
22
```

Working directory:

```text
app/frontend
```

### Steps

1. Checkout repository.
2. Configure Node.js 22.
3. Restore npm cache.
4. Install dependencies with `npm ci`.
5. Run ESLint.
6. Build the production frontend.
7. Run npm dependency auditing.

Commands executed:

```bash
npm ci
npm run lint
npm run build
npm audit --audit-level=high
```

A failure in any of these steps fails the frontend CI job.

---

## 2. Backend CI

The backend job runs on:

```text
ubuntu-latest
```

Python version:

```text
3.12
```

Working directory:

```text
app/backend
```

### Steps

1. Checkout repository.
2. Configure Python 3.12.
3. Restore pip cache.
4. Install Python dependencies.
5. Run unit tests while excluding integration tests.
6. Install `pip-audit`.
7. Audit Python dependencies.

Commands:

```bash
pip install -r requirements.txt
pytest -v tests --ignore=tests/integration
pip install pip-audit
pip-audit -r requirements.txt --strict
```

---

# Secret Detection

## Gitleaks

The `secret-scan` job checks the repository for accidentally committed secrets.

Gitleaks runs against the full repository history because the workflow uses:

```text
fetch-depth: 0
```

The GitHub token is supplied through the workflow environment.

A detected secret causes the security scan to fail.

---

# Container Build and Security

The Docker job depends on:

```text
frontend
backend
secret-scan
```

Therefore Docker builds do not begin until the application CI and secret detection jobs succeed.

The job builds both production container images.

### Backend

```bash
docker build \
  -t gambit-backend:${GITHUB_SHA} \
  ./app/backend
```

### Frontend

```bash
docker build \
  -t gambit-frontend:${GITHUB_SHA} \
  ./app/frontend
```

---

## Trivy Container Scanning

Trivy scans both locally built images.

The current workflow blocks on:

```text
CRITICAL
```

vulnerabilities that are not fixed.

The scan uses:

```text
--severity CRITICAL
--exit-code 1
--ignore-unfixed
```

Therefore:

* Fixed CRITICAL vulnerabilities can fail the build.
* Unfixed vulnerabilities are ignored by the current Trivy configuration.
* HIGH and MEDIUM findings are not currently blocking conditions in these image-scan commands.

This behavior should be kept synchronized with the project's security policy.

---

# Integration Testing

The integration-test job depends on the successful Docker build and security scan.

The Gambit local stack is started with:

```bash
docker compose up -d --build
```

The test environment includes:

```text
POSTGRES_DB=platform
POSTGRES_USER=platform
POSTGRES_PASSWORD=platform
FRONTEND_URL=http://localhost:5173
ENVIRONMENT=development
APP_VERSION=1.0.0
```

The pipeline then:

1. Checks running containers.
2. Waits for PostgreSQL readiness.
3. Waits for backend `/health`.
4. Runs backend integration tests.
5. Collects Docker Compose logs if a failure occurs.
6. Shuts down the test environment.

PostgreSQL readiness is checked with:

```bash
pg_isready -U platform -d platform
```

Backend readiness is checked with:

```text
http://localhost:8000/health
```

Integration tests are executed with:

```bash
pytest -v tests/integration
```

The environment is always cleaned up with:

```bash
docker compose down -v
```

---

# Production Image Publishing

The `ecr` job runs only for a push to `develop`.

It depends on:

```text
integration-test
```

AWS authentication uses GitHub Actions OIDC.

AWS role:

```text
GitHubActionsECRRole
```

AWS region:

```text
eu-west-2
```

The workflow verifies the assumed AWS identity with:

```bash
aws sts get-caller-identity
```

It then authenticates to Amazon ECR.

---

## ECR Repositories

Production images are pushed to:

```text
gambit-backend
gambit-frontend
```

Images are tagged using the Git commit SHA:

```text
${github.sha}
```

Example:

```text
gambit-backend:<commit-sha>
gambit-frontend:<commit-sha>
```

This provides an immutable reference to the source revision used to build the deployment image, although the ECR repositories currently permit mutable tags.

---

# ECS Deployment

The `ecs-deploy` job runs only after the ECR publishing job succeeds.

It uses the same GitHub OIDC role:

```text
GitHubActionsECRRole
```

Region:

```text
eu-west-2
```

Cluster:

```text
gambit-production
```

---

## 1. Download Current Task Definitions

The workflow retrieves the currently registered production task definitions:

```text
gambit-production-backend
gambit-production-frontend
```

This allows the deployment workflow to modify the existing task definitions rather than constructing them from scratch.

---

## 2. Configure Production CORS

The backend task definition is updated with the production frontend origin:

```text
http://gambit-production-alb-563168449.eu-west-2.elb.amazonaws.com
```

The existing `FRONTEND_URL` value is removed before the production value is inserted.

---

## 3. Update Container Images

The task definitions are rendered with the images built from the current Git commit.

Backend:

```text
gambit-backend:<github.sha>
```

Frontend:

```text
gambit-frontend:<github.sha>
```

---

## 4. Register Backend Task Definition

The updated backend task definition is registered with ECS.

The resulting task-definition ARN is stored in the workflow environment for the migration step and later service deployment.

---

# Database Migration

Database migrations run **before the production ECS services are updated**.

The workflow starts a temporary Fargate task using the newly registered backend task definition.

The migration command is:

```bash
alembic upgrade head
```

The migration task uses:

```text
Cluster:
  gambit-production

Launch type:
  FARGATE

Platform:
  1.4.0

Public IP:
  DISABLED
```

The task runs inside the production VPC using the configured private networking and security group.

---

## Migration Validation

The workflow waits for the migration task to stop.

It then checks:

* ECS task status
* Stop reason
* Container status
* Container exit code
* CloudWatch log stream

A backend container exit code other than `0` causes the deployment to fail.

When migration fails, the workflow attempts to retrieve the migration container logs from:

```text
/ecs/gambit-production
```

A successful migration produces:

```text
Database migration completed successfully.
```

---

# Frontend Task Definition

After successful database migration, the updated frontend task definition is registered with ECS.

The resulting task-definition ARN is stored for deployment.

---

# ECS Service Update

The backend service is updated first:

```text
gambit-production-backend
```

The frontend service is then updated:

```text
gambit-production-frontend
```

Both services use the newly registered task definitions.

---

# Deployment Stability

After updating the services, the workflow waits for ECS service stability.

Backend:

```bash
aws ecs wait services-stable \
  --cluster gambit-production \
  --services gambit-production-backend
```

Frontend:

```bash
aws ecs wait services-stable \
  --cluster gambit-production \
  --services gambit-production-frontend
```

If ECS does not reach the expected stable state, the deployment job fails.

---

# Production Verification

The final workflow step queries both ECS services.

The following values are reported:

```text
Service name
Desired count
Running count
Pending count
Service status
```

This provides a final deployment-state check after ECS reports service stability.

---

# Deployment Sequence

The complete production sequence is:

```text
1. Push to develop
       |
       v
2. Frontend CI
       |
       +---- npm ci
       +---- lint
       +---- build
       +---- npm audit
       |
       v
3. Backend CI
       |
       +---- pip install
       +---- pytest
       +---- pip-audit
       |
       v
4. Gitleaks
       |
       v
5. Docker build
       |
       +---- Backend image
       +---- Frontend image
       |
       v
6. Trivy scan
       |
       v
7. Integration tests
       |
       v
8. Authenticate to AWS using OIDC
       |
       v
9. Push images to ECR
       |
       v
10. Download current ECS task definitions
       |
       v
11. Replace application images
       |
       v
12. Register backend task definition
       |
       v
13. Run Alembic migration
       |
       v
14. Register frontend task definition
       |
       v
15. Update backend ECS service
       |
       v
16. Update frontend ECS service
       |
       v
17. Wait for ECS stability
       |
       v
18. Verify service state
```

---

# Failure Handling

## Frontend CI Failure

Check:

```bash
cd app/frontend
npm ci
npm run lint
npm run build
npm audit --audit-level=high
```

Resolve the reported issue and push a new commit.

---

## Backend CI Failure

Check:

```bash
cd app/backend
pip install -r requirements.txt
pytest -v tests --ignore=tests/integration
pip-audit -r requirements.txt --strict
```

Resolve test or dependency issues before deployment.

---

## Secret Detection Failure

Review the Gitleaks output.

Do not simply suppress the finding if an actual credential has been exposed.

If a real credential was committed, rotate the affected credential and remove it from the repository history according to the incident-response procedure.

---

## Docker/Trivy Failure

Inspect the affected image:

```bash
docker images
```

Review the Trivy findings and update the affected base image or dependency where appropriate.

The current CI configuration blocks on fixed CRITICAL findings.

---

## Integration Test Failure

Inspect the Compose environment:

```bash
docker compose ps
docker compose logs
```

Check PostgreSQL and backend health.

The CI workflow automatically collects logs when the integration-test job fails.

---

## ECR Failure

Verify:

* GitHub Actions OIDC authentication
* AWS role assumption
* AWS region
* ECR repository names
* IAM permissions
* Docker image build status

Confirm AWS identity:

```bash
aws sts get-caller-identity
```

---

## Migration Failure

Inspect the GitHub Actions migration output and CloudWatch logs.

The migration task must complete successfully before ECS services are updated.

Do not manually force the production services forward when the migration step has failed without first determining whether the database schema and application version are compatible.

---

## ECS Deployment Failure

Check:

```bash
aws ecs describe-services \
  --region eu-west-2 \
  --cluster gambit-production \
  --services \
    gambit-production-backend \
    gambit-production-frontend
```

Review:

* Running task count
* Pending task count
* Deployment status
* Task definition revision
* ECS service events

Then inspect CloudWatch logs:

```text
/ecs/gambit-production
```

---

# Rollback

The current deployment model uses ECS task-definition revisions.

If a deployment introduces an application problem, identify the previously working task-definition revision and update the affected ECS service to that revision.

Example:

```bash
aws ecs update-service \
  --region eu-west-2 \
  --cluster gambit-production \
  --service gambit-production-backend \
  --task-definition <previous-task-definition>
```

Then wait for service stability:

```bash
aws ecs wait services-stable \
  --region eu-west-2 \
  --cluster gambit-production \
  --services gambit-production-backend
```

Repeat for the frontend service when required.

Database rollback requires additional consideration because an application deployment may already have applied an Alembic migration. Database migrations should therefore be reviewed for backward compatibility before production deployment.

---

# Deployment Architecture Responsibility

Terraform manages the core AWS infrastructure.

GitHub Actions manages the application delivery path, including:

* Container image publishing
* ECS task-definition revisions
* Database migration execution
* ECS service deployment

This separation is intentional: Terraform provisions infrastructure while the CI/CD pipeline delivers application revisions.

---

# Current CI/CD Limitations

The current pipeline has the following documented limitations:

* Production deployment is currently triggered from `develop`.
* Trivy image scanning currently blocks on CRITICAL findings only.
* Trivy ignores unfixed vulnerabilities.
* ECR push-time scanning is disabled.
* ECR image tags remain mutable.
* Production ALB traffic currently uses HTTP rather than HTTPS.
* ECS services currently use a desired count of one.
* Database migration rollback is not automated.
* ECS deployment rollback is not automatically triggered by the workflow.

These limitations are documented for future hardening work.

---

# Related Documentation

* `README.md`
* `docs/architecture.md`
* `security/security-policy.md`
* `docs/cicd-runbook.md`
* `.github/workflows/ci.yml`

**Runbook Version:** 1.0
**Environment:** Production
**AWS Region:** `eu-west-2`
