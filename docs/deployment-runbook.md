# Gambit Production Deployment Runbook

## 1. Purpose

This runbook defines the operational procedure for deploying, validating, troubleshooting, and rolling back Gambit application releases in the production AWS environment.

It covers:

- Production deployment prerequisites
- GitHub Actions deployment flow
- ECS task-definition revisions
- Database migration handling
- Post-deployment validation
- Deployment failure handling
- ECS rollback
- Production verification commands
- Operational limitations

Infrastructure provisioning is managed by Terraform. Application releases are deployed through GitHub Actions to Amazon ECS on AWS Fargate.

---

## 2. Production Environment

| Component | Configuration |
|---|---|
| AWS Region | `eu-west-2` |
| ECS Cluster | `gambit-production` |
| Backend Service | `gambit-production-backend` |
| Frontend Service | `gambit-production-frontend` |
| Compute | AWS Fargate |
| Backend Port | `8000` |
| Frontend Port | `80` |
| Desired Backend Tasks | `1` |
| Desired Frontend Tasks | `1` |
| Fargate Platform | `1.4.0` backend |
| ECS Public IP | Disabled |
| Container Logs | CloudWatch Logs |
| Database | Amazon RDS PostgreSQL |

ECS tasks run in private subnets and receive traffic through the Application Load Balancer.

---

## 3. Deployment Architecture

The production deployment path is:

```
Developer
   |
   | git push to develop
   v
GitHub Actions
   |
   +--> Frontend tests
   +--> Backend tests
   +--> Secret scanning
   +--> Docker builds
   +--> Trivy image scanning
   +--> Integration tests
   |
   v
Amazon ECR
   |
   | push immutable Git SHA image
   v
ECS task definition
   |
   +--> Database migration task
   |
   +--> Backend ECS service
   |
   +--> Frontend ECS service
   |
   v
Application Load Balancer
   |
   +--> Backend
   +--> Frontend
```

GitHub Actions performs:

- Frontend validation
- Backend validation
- Secret scanning
- Docker image build
- Container vulnerability scanning
- Docker Compose integration testing
- ECR image push
- ECS task-definition registration
- Database migration
- ECS service update
- ECS service stabilization

The production deployment workflow is defined in: `.github/workflows/ci.yml`

The detailed CI/CD implementation is documented in: `docs/cicd-runbook.md`

---

## 4. Deployment Trigger

The production deployment path is triggered by a push to: `develop`

The workflow must complete the required CI stages before deployment proceeds.

The production path includes:

- Frontend validation
- Backend validation
- Secret scanning
- Docker image build
- Container vulnerability scanning
- Docker Compose integration testing
- ECR image push
- ECS task-definition registration
- Database migration
- ECS service update
- ECS service stabilization

A pull request or main branch workflow does not use the production ECR/ECS deployment path.

---

## 5. Pre-Deployment Checklist

Before deploying a production change, verify:

- The change has been reviewed
- The working tree contains the intended changes
- The application builds successfully
- Backend tests pass
- Frontend lint/build checks pass
- Secret scanning passes
- Container security scanning passes
- Integration tests pass
- Database migrations have been reviewed if the schema changes
- The migration is compatible with the application version being deployed
- No production credentials are present in source code
- The deployment is being made through the approved GitHub Actions workflow

Check the local repository state with:

```bash
git status
```

Check the commit intended for deployment with:

```bash
git log -1 --oneline
```

---

## 6. Normal Deployment Procedure

### Step 1 — Push the Release

Push the approved commit to develop:

```bash
git push origin develop
```

GitHub Actions starts the Gambit CI workflow.

### Step 2 — Monitor CI

Monitor the workflow in GitHub Actions.

The deployment must pass:

- frontend
- backend
- secret-scan
- docker
- integration-test
- ecr
- ecs-deploy

Do not manually update ECS while the normal deployment workflow is still running unless performing an emergency recovery procedure.

---

## 7. Container Image Deployment

Successful CI builds images using the Git commit SHA.

The production ECR repositories are:

- gambit-backend
- gambit-frontend

Images are pushed using the commit SHA as the image tag.

This allows a deployment to identify the exact application revision running in ECS.

The image tag can be obtained locally with:

```bash
git rev-parse HEAD
```

---

## 8. ECS Task Definition Deployment

GitHub Actions retrieves the current production task definitions:

- gambit-production-backend
- gambit-production-frontend

The workflow renders new task definitions with the newly built ECR images.

The new task definitions are then registered with ECS.

The ECS services are updated to use the newly registered revisions.

### Important Terraform behavior

Terraform manages the baseline ECS service configuration, but the services contain:

```hcl
lifecycle {
  ignore_changes = [
    task_definition
  ]
}
```

Therefore Terraform does not continuously overwrite the application task-definition revision deployed by GitHub Actions.

Application releases should therefore use the GitHub Actions deployment workflow rather than manually changing the task definition through Terraform.

---

## 9. Database Migration

Database migrations run before the ECS services are updated.

GitHub Actions:

- Registers the new backend task definition
- Starts a one-off Fargate task
- Uses the production ECS networking configuration
- Runs: `alembic upgrade head`
- Waits for the migration task to stop
- Checks the backend container exit code
- Retrieves CloudWatch logs if the migration fails

A failed migration stops the deployment before the application services are updated.

### Migration safety

Production migrations should be designed to be backward compatible with the currently running application whenever possible.

Avoid destructive schema changes that cannot coexist with the previous application revision.

Before deploying a schema-changing release, review the Alembic revision:

```bash
cd ~/Bandit/Gambit/app/backend
alembic history
```

Check the current migration:

```bash
alembic current
```

Do not manually run production migrations unless performing an approved recovery procedure.

---

## 10. ECS Service Update

After a successful migration, GitHub Actions updates:

- gambit-production-backend
- gambit-production-frontend

The services use: `launch_type = FARGATE`

**Backend:**

- CPU: 256
- Memory: 512 MiB
- Port: 8000
- Platform: 1.4.0

**Frontend:**

- CPU: 256
- Memory: 512 MiB
- Port: 80

**Both services:**

- run without public IP addresses
- run in private subnets
- use the ECS security group
- are registered with an ALB target group

---

## 11. Verify ECS Deployment

After deployment, verify the services:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Service:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status,TaskDefinition:taskDefinition}' \
  --output table
```

Expected state:

- Desired = 1
- Running = 1
- Pending = 0
- Status = ACTIVE

The deployed task-definition ARN should correspond to the newly registered revision.

---

## 12. Verify ECS Tasks

List running tasks:

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --desired-status RUNNING \
  --region eu-west-2
```

Describe backend tasks:

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --service-name gambit-production-backend \
  --desired-status RUNNING \
  --region eu-west-2
```

Describe frontend tasks:

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --service-name gambit-production-frontend \
  --desired-status RUNNING \
  --region eu-west-2
```

---

## 13. Verify Load Balancer Health

The ECS services are behind the production Application Load Balancer.

Check backend target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <BACKEND_TARGET_GROUP_ARN> \
  --region eu-west-2
```

Check frontend target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <FRONTEND_TARGET_GROUP_ARN> \
  --region eu-west-2
```

Expected target state: **healthy**

The backend health endpoint is: `/health`

---

## 14. Application Validation

Obtain the ALB DNS name:

```bash
aws elbv2 describe-load-balancers \
  --names gambit-production-alb \
  --region eu-west-2 \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

Test the backend health endpoint:

```bash
curl -fsS http://<ALB_DNS_NAME>/health
```

Test the application information endpoint:

```bash
curl -fsS http://<ALB_DNS_NAME>/info
```

A successful response confirms that traffic is reaching the deployed application through the load balancer.

---

## 15. Verify CloudWatch Logs

The ECS services send container logs to: `/ecs/gambit-production`

List recent log streams:

```bash
aws logs describe-log-streams \
  --log-group-name /ecs/gambit-production \
  --region eu-west-2 \
  --order-by LastEventTime \
  --descending \
  --max-items 10
```

For a specific stream:

```bash
aws logs get-log-events \
  --log-group-name /ecs/gambit-production \
  --log-stream-name <LOG_STREAM_NAME> \
  --region eu-west-2
```

Review logs for:

- application startup errors
- database connection errors
- migration failures
- HTTP 5xx errors
- container crashes
- unexpected configuration errors

---

## 16. Deployment Success Criteria

A production deployment is considered operationally successful when:

- CI completes successfully
- Images are present in ECR
- The migration task exits successfully when migrations are required
- Backend ECS desired count is 1
- Backend ECS running count is 1
- Frontend ECS desired count is 1
- Frontend ECS running count is 1
- ECS services stabilize
- ALB targets report healthy
- `/health` responds successfully
- `/info` responds successfully
- CloudWatch logs show normal application startup
- No new critical deployment errors are observed

---

## 17. Deployment Failure Handling

### If CI fails before ECR deployment:

- Inspect the failed GitHub Actions job
- Correct the underlying issue
- Push a corrected commit
- Allow the full deployment pipeline to run again

Do not manually deploy an image that has failed the required CI controls.

### Migration failure

If the migration task fails:

- Do not continue with the application deployment
- Inspect the migration task status
- Review CloudWatch migration logs
- Identify whether the failure is caused by:
  - schema conflict
  - invalid migration
  - database connectivity
  - credentials
  - application/database compatibility
- Correct the migration
- Re-run the deployment through GitHub Actions

Do not manually modify production database schema to bypass a failed migration without an approved recovery procedure.

---

## 18. ECS Deployment Failure

If an ECS service fails to stabilize:

Check service events:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend \
  --region eu-west-2 \
  --query 'services[0].events[0:10].[createdAt,message]' \
  --output table
```

For the frontend:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[0].events[0:10].[createdAt,message]' \
  --output table
```

Check stopped tasks:

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --desired-status STOPPED \
  --region eu-west-2
```

Inspect a stopped task:

```bash
aws ecs describe-tasks \
  --cluster gambit-production \
  --tasks <TASK_ARN> \
  --region eu-west-2
```

Common areas to inspect:

- task-definition configuration
- ECR image availability
- container startup
- Secrets Manager access
- database connectivity
- ECS security group rules
- target-group health checks
- CloudWatch logs
- environment variables

---

## 19. ECS Rollback

If a newly deployed application revision is unhealthy, identify the previous known-good ECS task-definition revision.

List backend revisions:

```bash
aws ecs list-task-definitions \
  --family-prefix gambit-production-backend \
  --status ACTIVE \
  --sort DESC \
  --region eu-west-2
```

List frontend revisions:

```bash
aws ecs list-task-definitions \
  --family-prefix gambit-production-frontend \
  --status ACTIVE \
  --sort DESC \
  --region eu-west-2
```

Update the affected service to the previous task definition:

```bash
aws ecs update-service \
  --cluster gambit-production \
  --service gambit-production-backend \
  --task-definition <PREVIOUS_BACKEND_TASK_DEFINITION_ARN> \
  --region eu-west-2
```

Frontend:

```bash
aws ecs update-service \
  --cluster gambit-production \
  --service gambit-production-frontend \
  --task-definition <PREVIOUS_FRONTEND_TASK_DEFINITION_ARN> \
  --region eu-west-2
```

Wait for stabilization:

```bash
aws ecs wait services-stable \
  --cluster gambit-production \
  --services gambit-production-backend \
  --region eu-west-2
```

Repeat for the frontend if required.

After rollback, verify:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Service:serviceName,Desired:desiredCount,Running:runningCount,TaskDefinition:taskDefinition}' \
  --output table
```

Then validate the ALB health endpoints.

---

## 20. Database Rollback Considerations

Application rollback and database rollback are separate operations.

Rolling an ECS service back to an earlier task definition does not automatically reverse an Alembic migration.

Before performing a database rollback:

- identify the migration revision
- determine whether the migration is reversible
- assess application/schema compatibility
- preserve required database data
- review the available RDS recovery options

The production RDS instance has deletion protection enabled and automated backup/PITR capability.

Database recovery procedures are documented separately in: `docs/dr-runbook.md`

---

## 21. Emergency Deployment Principle

Manual ECS commands should be reserved for:

- production incident recovery
- controlled rollback
- CI/CD recovery
- operational troubleshooting

Normal releases should continue to use:

```
Git push
    ↓
GitHub Actions
    ↓
ECR
    ↓
ECS
```

Manual changes must be documented so the production state can be reconciled with the intended infrastructure configuration.

---

## 22. Terraform and Application Deployment Boundary

**Terraform manages:**

- ECS cluster
- ECS services
- task-definition baseline
- networking
- load balancer integration
- execution role configuration
- CloudWatch logging configuration

**GitHub Actions manages:**

- container image build
- ECR image push
- production task-definition rendering
- task-definition registration
- database migration execution
- ECS service deployment

Because the ECS services ignore task-definition changes in Terraform, application task-definition revisions should not be managed by manually changing Terraform image tags for every application release.

---

## 23. Operational Limitations

Current production deployment limitations include:

- ECS backend desired count is 1
- ECS frontend desired count is 1
- ECS services do not currently provide multiple running application tasks
- The production ALB currently uses HTTP rather than HTTPS
- RDS Multi-AZ is disabled
- RDS backup retention is currently 1 day
- A production restore drill has not been completed
- ECR image scanning on push is currently disabled
- ECR tags remain mutable, although Git SHA tags are used by the CI/CD deployment process
- Some IAM policies still contain broader resource scopes than the final least-privilege target

These limitations should be considered during incident response and deployment planning.

---

## 24. Related Documentation

- `README.md` — project overview and production status
- `docs/architecture.md` — production architecture
- `docs/cicd-runbook.md` — CI/CD implementation and pipeline operation
- `security/security-policy.md` — security controls and requirements
- `docs/dr-runbook.md` — disaster recovery procedures
- `docs/incident-response.md` — incident response procedures
