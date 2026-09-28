# Gambit Incident Response Runbook

## 1. Overview

This document defines the incident-response process for the Gambit production platform.

It provides a structured procedure for detecting, triaging, containing, recovering from, and documenting production incidents affecting:

* Application availability
* ECS services and tasks
* Application Load Balancer health
* RDS PostgreSQL
* Database migrations
* CI/CD deployments
* Container images
* AWS infrastructure
* Monitoring and alerting
* Security-sensitive events

The objective is to restore service safely while preserving evidence and avoiding unnecessary changes during an active incident.

---

## 2. Scope

This runbook applies to the Gambit production environment deployed in AWS region:

```text
eu-west-2
```

Primary components include:

```text
Internet
   |
   v
Application Load Balancer
   |
   +----------------------+
   |                      |
   v                      v
Frontend ECS Service   Backend ECS Service
   |                      |
   |                      v
   |                  RDS PostgreSQL
   |
   v
CloudWatch Logs
   |
   v
CloudWatch Alarms
   |
   v
SNS Alerts
```

The platform uses:

* Amazon ECS Fargate
* Amazon ECR
* Application Load Balancer
* Amazon RDS PostgreSQL
* AWS Secrets Manager
* Amazon CloudWatch
* Amazon SNS
* GitHub Actions
* Terraform
* Alembic

---

## 3. Incident Severity

Incident severity should be determined by customer impact, service availability, scope, and security implications.

### Severity 1 — Critical

Use for incidents involving complete or near-complete production unavailability or serious security events.

Examples:

* ALB cannot reach either production application service
* Backend unavailable and frontend cannot perform its primary functions
* RDS unavailable with significant application impact
* Confirmed credential or secret exposure
* Significant unauthorized AWS activity
* Production deployment causes widespread service failure

Immediate priorities:

1. Stabilize the environment.
2. Preserve relevant evidence.
3. Restore service.
4. Determine whether rollback or recovery is required.
5. Document the incident.

---

### Severity 2 — Major

Use for significant degradation affecting an important part of the platform.

Examples:

* Backend service repeatedly restarting
* Elevated 5xx responses
* Unhealthy ALB targets
* Failed production deployment with partial service impact
* Database connectivity problems with intermittent application impact
* Significant resource exhaustion

Priorities:

1. Identify the affected component.
2. Contain the problem.
3. Restore normal operation.
4. Investigate the underlying cause.

---

### Severity 3 — Minor

Use for limited degradation or non-critical operational problems.

Examples:

* A single ECS task restart
* Temporary elevated CPU
* Non-critical CI failure
* Isolated application error
* Monitoring anomaly without confirmed customer impact

Priorities:

1. Investigate.
2. Correct the problem.
3. Confirm service health.
4. Record the event if operationally useful.

---

## 4. Incident Response Lifecycle

All production incidents should follow this general lifecycle:

```text
Detect
  |
  v
Triage
  |
  v
Assess Impact
  |
  v
Contain
  |
  v
Recover
  |
  v
Validate
  |
  v
Monitor
  |
  v
Document
  |
  v
Review
```

Avoid making unrelated infrastructure changes while an incident is active.

---

## 5. Detection Sources

Incidents may be detected through:

### CloudWatch Alarms

Configured Gambit alarms include conditions for:

* ECS CPU utilization
* ECS memory utilization
* No running ECS tasks
* ALB HTTP 5xx responses
* Unhealthy ALB targets

### SNS

CloudWatch alarms publish notifications through:

```text
gambit-production-alerts
```

### ECS

ECS service and task state may reveal:

* Stopped tasks
* Failed task launches
* Repeated restarts
* Deployment failures
* Health-check failures

### Application Logs

Application logs are stored in:

```text
/ecs/gambit-production
```

### GitHub Actions

CI/CD failures may identify:

* Test failures
* Security scan failures
* Image build failures
* ECR push failures
* ECS deployment failures
* Migration failures

---

## 6. Initial Response

When an incident is detected:

### Step 1 — Confirm the Incident

Do not immediately assume that an alarm represents a production outage.

Check:

* Current application availability
* ECS service state
* ALB target health
* Recent deployments
* CloudWatch alarms
* Application logs

---

### Step 2 — Establish the Incident Time

Record:

```text
Incident start:
Detection time:
First observed impact:
```

Use UTC when recording infrastructure events.

AWS CLI timestamps and CloudWatch event timestamps should be treated as the authoritative infrastructure timeline.

---

### Step 3 — Identify the Affected Component

Determine whether the issue affects:

```text
ALB
ECS frontend
ECS backend
RDS PostgreSQL
Secrets Manager
ECR
GitHub Actions
Terraform/infrastructure
Application code
Network/security configuration
```

---

### Step 4 — Check Recent Changes

Recent changes are an important diagnostic signal.

Review:

```bash
git log --oneline -10
```

Review GitHub Actions runs and identify whether a deployment occurred shortly before the incident.

Check ECS deployments:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Service:serviceName,Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Deployments:deployments[*].{Status:status,Running:runningCount,Desired:desiredCount,TaskDefinition:taskDefinition}}' \
  --output json
```

---

## 7. Immediate Triage Commands

### 7.1 Check ECS Services

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Service:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status}' \
  --output table
```

Expected state:

```text
Desired = 1
Running = 1
Pending = 0
Status = ACTIVE
```

The exact values may differ during an active deployment.

---

### 7.2 List Recent ECS Tasks

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --region eu-west-2 \
  --desired-status STOPPED \
  --output text
```

Inspect stopped tasks:

```bash
aws ecs describe-tasks \
  --cluster gambit-production \
  --tasks <TASK_ARN> \
  --region eu-west-2 \
  --query 'tasks[].{Task:taskArn,LastStatus:lastStatus,StopCode:stopCode,StoppedReason:stoppedReason,Containers:containers[*].{Name:name,ExitCode:exitCode,Reason:reason}}' \
  --output json
```

Do not assume that every stopped task represents an incident. ECS may stop old tasks during normal deployments.

---

## 8. Application Load Balancer Triage

### Check ALB DNS

```bash
aws elbv2 describe-load-balancers \
  --region eu-west-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `gambit-production`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
  --output table
```

### Check Target Groups

```bash
aws elbv2 describe-target-groups \
  --region eu-west-2 \
  --query 'TargetGroups[?contains(TargetGroupName, `gambit-production`)].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthPath:HealthCheckPath,ARN:TargetGroupArn}' \
  --output table
```

### Check Target Health

Use the target group ARN returned above:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region eu-west-2 \
  --output table
```

Investigate:

```text
healthy
unhealthy
initial
draining
unused
```

An unhealthy backend target should be correlated with ECS task health and application logs.

---

## 9. Backend Health Check

The backend exposes:

```text
/health
```

The ALB uses this endpoint for backend health validation.

If the application is reachable through the ALB, test:

```bash
curl -i http://<ALB_DNS>/health
```

A successful health response confirms that the request is reaching the backend health endpoint.

A failed request does not by itself identify the root cause.

Investigate:

```text
ALB
  -> target group
  -> ECS task
  -> application process
  -> database dependency
```

---

## 10. CloudWatch Log Investigation

The primary production log group is:

```text
/ecs/gambit-production
```

Tail recent logs:

```bash
aws logs tail /ecs/gambit-production \
  --region eu-west-2 \
  --since 30m \
  --follow
```

For a shorter investigation:

```bash
aws logs tail /ecs/gambit-production \
  --region eu-west-2 \
  --since 10m
```

Look for:

```text
ERROR
Exception
Traceback
database connection failures
timeout
authentication failures
startup failures
migration errors
health-check failures
```

Do not treat a single application exception as proof of the root cause without correlating it with infrastructure and deployment events.

---

## 11. ECS Task Failure Investigation

If tasks repeatedly stop:

### Step 1

Identify stopped tasks:

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --desired-status STOPPED \
  --region eu-west-2
```

### Step 2

Inspect the stopped reason:

```bash
aws ecs describe-tasks \
  --cluster gambit-production \
  --tasks <TASK_ARN> \
  --region eu-west-2 \
  --query 'tasks[].{StoppedReason:stoppedReason,StopCode:stopCode,Containers:containers[*].{Name:name,ExitCode:exitCode,Reason:reason}}' \
  --output json
```

### Step 3

Correlate with application logs.

### Step 4

Check whether the failure started after:

* New application image
* New task definition
* Configuration change
* Secret change
* Database migration
* Infrastructure change

---

## 12. Common ECS Failure Categories

### Container exits immediately

Investigate:

* Application startup failure
* Missing environment variable
* Invalid configuration
* Dependency failure
* Image problem
* Database connection failure

### Health check failures

Investigate:

* Application process
* `/health` endpoint
* Container port
* ECS port mapping
* ALB target group
* Security group rules
* Startup time

### Cannot pull image

Investigate:

* ECR image existence
* Task execution role
* ECR permissions
* Network access
* Image tag

### Cannot retrieve secret

Investigate:

* Secrets Manager secret availability
* ECS execution role
* Secret ARN
* IAM permissions
* Region

The application task does not use a separate ECS task role for application AWS API access. The execution role is used for ECS image and secret retrieval.

---

## 13. RDS Incident Response

RDS PostgreSQL is a critical backend dependency.

First identify the active instance:

```bash
aws rds describe-db-instances \
  --region eu-west-2 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `gambit`)].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Version:EngineVersion,Endpoint:Endpoint.Address,Port:Endpoint.Port,MultiAZ:MultiAZ,Public:PubliclyAccessible,DeletionProtection:DeletionProtection}' \
  --output table
```

Check:

```text
DBInstanceStatus
Endpoint
EngineVersion
MultiAZ
PubliclyAccessible
DeletionProtection
```

---

### RDS Status

If status is not:

```text
available
```

investigate the RDS event history and CloudWatch metrics.

Do not immediately modify the database configuration during an incident unless the change is part of an established recovery procedure.

---

### Database Connectivity Failure

Potential causes include:

* RDS unavailable
* Incorrect database configuration
* Secret mismatch
* Security group rules
* ECS task/network configuration
* Database connection exhaustion
* Application configuration issue

Check the application logs first.

Do not assume that lack of NAT connectivity is the cause. The production ECS-to-RDS path is private and does not require internet NAT for normal database connectivity.

---

## 14. Database Migration Incidents

Gambit runs Alembic migrations during the deployment workflow.

The migration process occurs before the ECS services are updated to the new application revision.

Conceptually:

```text
Register backend task definition
          |
          v
Run Alembic migration
          |
       success?
       /      \
     no        yes
     |          |
   stop       update
 deployment   services
```

If migration fails:

1. Do not continue the deployment.
2. Inspect the migration task logs.
3. Determine whether the failure is connectivity, permissions, syntax, or schema related.
4. Check whether the migration changed the database before failing.
5. Do not blindly rerun a migration until its state is understood.

Retrieve recent ECS tasks and inspect the migration task's stopped reason and logs.

---

## 15. Deployment Incident Response

A production deployment is normally triggered by a push to:

```text
develop
```

Pull requests and pushes to `main` run CI, but the production ECR/ECS deployment path is restricted to pushes to `develop`.

If a deployment fails:

### Step 1 — Check GitHub Actions

Identify the failed job:

```text
frontend
backend
secret-scan
docker
integration-test
ecr
ecs-deploy
```

### Step 2 — Determine Failure Stage

Examples:

```text
CI test failure
Security scan failure
Docker build failure
ECR push failure
Task-definition registration failure
Migration failure
ECS deployment failure
Service stabilization failure
```

### Step 3 — Determine Whether Production Was Changed

A failed CI job may not have modified production.

A failure during ECS deployment may have partially changed production.

Confirm actual ECS service state before attempting rollback.

---

## 16. Deployment Rollback

If a newly deployed application revision is confirmed to be the cause of an incident:

1. Identify the previous healthy task definition revision.
2. Confirm the previous revision is compatible with the current database schema.
3. Update the affected ECS service to the previous task definition.
4. Wait for the service to stabilize.
5. Verify ALB target health.
6. Verify application health.
7. Monitor logs and alarms.

Example:

```bash
aws ecs update-service \
  --cluster gambit-production \
  --service gambit-production-backend \
  --task-definition <PREVIOUS_TASK_DEFINITION> \
  --region eu-west-2
```

For the frontend:

```bash
aws ecs update-service \
  --cluster gambit-production \
  --service gambit-production-frontend \
  --task-definition <PREVIOUS_TASK_DEFINITION> \
  --region eu-west-2
```

Wait for stabilization:

```bash
aws ecs wait services-stable \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2
```

Rollback application code does **not** automatically roll back database migrations.

Database rollback must be treated as a separate recovery decision.

---

## 17. Security Incident Response

Security incidents require immediate containment and evidence preservation.

Examples include:

* Secret exposure
* Credential leakage
* Unexpected IAM activity
* Unauthorized ECR access
* Unexpected AWS resource changes
* Suspicious GitHub Actions activity

### Immediate Actions

1. Stop further exposure where possible.
2. Identify the affected credential or resource.
3. Preserve logs and relevant timestamps.
4. Rotate compromised credentials.
5. Review IAM and CloudTrail activity where available.
6. Determine affected systems.
7. Verify that the exposed secret is no longer usable.
8. Document the incident.

Do not delete evidence before determining what information is required for investigation.

---

## 18. Secret Exposure

If an application secret, database credential, token, or other sensitive value is committed or exposed:

### Do not

* Leave the credential active.
* Assume deleting the Git commit is sufficient.
* Paste the secret into an incident ticket or chat.
* Commit a replacement secret to the repository.

### Do

1. Identify the exposed credential.
2. Rotate or replace it.
3. Update the authoritative secret store.
4. Restart affected ECS tasks if required.
5. Verify application connectivity.
6. Review repository and CI history.
7. Determine whether unauthorized access occurred.

Gambit's production database credentials are managed through AWS Secrets Manager and injected into the backend ECS task definition.

---

## 19. CI/CD Security Failure

If Gitleaks detects a potential secret:

```text
Stop the deployment.
```

Do not bypass the scan simply to continue production deployment.

If Trivy detects a blocking image vulnerability:

1. Identify the affected package/image.
2. Determine whether the finding is fixed or unfixed.
3. Review the image build.
4. Update the affected dependency/base image where appropriate.
5. Rebuild and rescan.
6. Only deploy after the pipeline passes.

The current Trivy enforcement blocks fixed `CRITICAL` findings and uses `--ignore-unfixed`.

---

## 20. IAM Incident

If an IAM permission or role appears responsible:

Investigate:

```text
GitHubActionsECRRole
ecs_task_execution role
```

Determine whether the issue affects:

* ECR access
* ECS deployment
* Secrets Manager access
* CloudWatch logging
* ECS task startup

Do not broadly grant administrative permissions as an emergency workaround unless absolutely necessary and explicitly controlled.

Prefer the smallest permission required to restore the affected operation.

---

## 21. High CPU or Memory

CloudWatch alarms may identify:

```text
CPU utilization > 80%
Memory utilization > 80%
```

First determine whether the increase is:

* Temporary
* Deployment-related
* Traffic-related
* Application-related
* Resource exhaustion

Check ECS service state:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Service:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table
```

Then inspect application logs.

Current production tasks use:

```text
CPU:    256
Memory: 512 MiB
```

Do not assume increasing resources is the correct permanent fix. Establish the cause first.

---

## 22. No Running ECS Tasks

If the `No Running Tasks` alarm fires:

### Check service state

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --output json
```

### Check recent stopped tasks

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --desired-status STOPPED \
  --region eu-west-2
```

### Check task failure reasons

```bash
aws ecs describe-tasks \
  --cluster gambit-production \
  --tasks <TASK_ARN> \
  --region eu-west-2 \
  --output json
```

Common areas to investigate:

```text
ECR image
ECS execution role
Secrets Manager
network configuration
security groups
container startup
application configuration
health checks
```

---

## 23. ALB 5xx Incident

If the ALB 5xx alarm fires:

1. Confirm whether errors are continuing.
2. Check backend target health.
3. Check ECS service state.
4. Check application logs.
5. Check recent deployments.
6. Determine whether the error is frontend or backend related.

Useful checks:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region eu-west-2
```

Then:

```bash
aws logs tail /ecs/gambit-production \
  --region eu-west-2 \
  --since 15m
```

Correlate the ALB errors with application timestamps.

---

## 24. Containment Principles

During an active incident:

### Prefer

* Reverting a known-bad deployment
* Stopping an unsafe deployment
* Restoring a known-good ECS revision
* Rotating exposed credentials
* Isolating the affected component
* Preserving logs and evidence

### Avoid

* Random Terraform changes
* Broad IAM permissions
* Deleting resources without investigation
* Unverified database changes
* Manual changes that conflict with GitHub Actions
* Destructive RDS operations
* Disabling security controls merely to make a deployment succeed

---

## 25. Terraform and Incident Response

Terraform is the infrastructure-as-code source for Gambit's AWS infrastructure.

However, production application task-definition revisions are managed through GitHub Actions.

The ECS services intentionally ignore task-definition drift:

```text
lifecycle {
  ignore_changes = [task_definition]
}
```

Therefore:

* Do not use Terraform as the first response to an application deployment incident.
* Do not run `terraform apply` merely to revert an application image.
* Use the deployment rollback procedure for application revisions.
* Use Terraform for infrastructure configuration changes.

Before making an infrastructure change during an incident, determine whether the change belongs to:

```text
Terraform-managed infrastructure
```

or:

```text
GitHub Actions-managed application deployment
```

---

## 26. RDS Recovery

If the RDS instance cannot be recovered through normal service restoration, use the dedicated DR runbook:

```text
docs/dr-runbook.md
```

Available recovery mechanisms include:

* Automated backups
* Point-in-time recovery
* Manual snapshots

Current limitations include:

* One-day automated backup retention
* Multi-AZ disabled
* No multi-region database replica
* No completed production restore drill
* No formally measured RTO/RPO

Do not initiate point-in-time recovery or snapshot restoration without confirming the required recovery point and impact.

---

## 27. Evidence Collection

For significant incidents, record:

```text
Incident ID:
Start time:
Detection time:
Affected services:
Customer impact:
Recent deployment:
ECS service state:
Task failure reason:
ALB target health:
Relevant logs:
CloudWatch alarms:
RDS status:
GitHub Actions run:
Actions taken:
Recovery time:
Root cause:
Follow-up actions:
```

Useful evidence includes:

* CloudWatch logs
* ECS task descriptions
* ECS service descriptions
* ALB target health
* RDS status/events
* GitHub Actions run information
* Git history
* Relevant Terraform changes
* Security findings

---

## 28. Recovery Validation

An incident should not be considered resolved immediately after the first successful request.

Verify:

### ECS

```text
Desired count correct
Running count correct
No unexpected task restarts
Deployment stable
```

### ALB

```text
Targets healthy
5xx errors returned to normal
Health checks passing
```

### Application

Verify:

```text
/health
/info
```

and representative application functionality.

### Database

Verify:

```text
Backend can connect
Required tables exist
Application database operations work
```

### Monitoring

Verify:

```text
CloudWatch logs flowing
Alarms normal
SNS alerting remains configured
```

---

## 29. Post-Incident Monitoring

After recovery, monitor the system for recurrence.

Recommended observation period should depend on the incident.

During monitoring, check:

* ECS task stability
* ALB target health
* ALB 5xx metrics
* CPU utilization
* Memory utilization
* Application logs
* RDS health
* CloudWatch alarms
* Deployment status

Do not close the incident solely because the immediate symptom disappeared.

---

## 30. Incident Closure

An incident may be closed when:

* Customer-facing service is restored.
* Affected infrastructure is stable.
* Monitoring is normal.
* No unexpected ECS task restarts are occurring.
* Relevant alarms have returned to normal.
* Security implications have been addressed where applicable.
* Evidence has been preserved.
* The incident record has been completed.

Record:

```text
Resolution time:
Duration:
Impact:
Root cause:
Recovery action:
Preventive action:
```

---

## 31. Root Cause Analysis

A post-incident review should distinguish:

### Trigger

The event that immediately caused the incident.

### Root Cause

The underlying technical condition that allowed the incident to occur.

### Contributing Factors

Conditions that increased the likelihood or impact.

### Detection

How the incident was identified.

### Recovery

What restored normal service.

### Prevention

What should change to reduce recurrence.

Avoid assigning blame. Focus on system behavior, controls, and process improvements.

---

## 32. Post-Incident Actions

Potential follow-up actions include:

* Improve health checks
* Increase observability
* Add missing CloudWatch alarms
* Improve application logging
* Increase ECS capacity
* Implement ECS autoscaling
* Improve database resilience
* Increase backup retention
* Perform a restore drill
* Implement Multi-AZ RDS
* Implement HTTPS/TLS
* Improve IAM least privilege
* Enable additional ECR scanning
* Improve deployment rollback automation
* Add automated smoke tests
* Improve migration safety
* Document recurring failure modes

Actions should be tracked as separate engineering tasks rather than left only in the incident document.

---

## 33. Current Operational Limitations

The current Gambit production environment has several limitations relevant to incident response:

| Area                        | Current State                          |
| --------------------------- | -------------------------------------- |
| ECS desired count           | 1 task per service                     |
| ECS autoscaling             | Not confirmed/configured               |
| RDS Multi-AZ                | Disabled                               |
| RDS backup retention        | 1 day                                  |
| Multi-region DR             | Not implemented                        |
| Production restore drill    | Not completed                          |
| Formal RTO                  | Not measured                           |
| Formal RPO                  | Not measured                           |
| ALB TLS                     | Not implemented; HTTP currently used   |
| ECR immutable tags          | Not enabled                            |
| ECR scan-on-push            | Not enabled                            |
| Application rollback        | Available through ECS task definitions |
| Database migration rollback | Manual decision; not automatic         |

These limitations should be considered when assessing incident impact and recovery options.

---

## 34. Emergency Command Reference

### ECS services

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --output table
```

### Stopped tasks

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --desired-status STOPPED \
  --region eu-west-2
```

### Logs

```bash
aws logs tail /ecs/gambit-production \
  --region eu-west-2 \
  --since 30m
```

### RDS

```bash
aws rds describe-db-instances \
  --region eu-west-2 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `gambit`)].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address}' \
  --output table
```

### ALB target health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region eu-west-2
```

### ECS rollback

```bash
aws ecs update-service \
  --cluster gambit-production \
  --service <SERVICE_NAME> \
  --task-definition <PREVIOUS_TASK_DEFINITION> \
  --region eu-west-2
```

---

## 35. Related Documentation

| Document                     | Purpose                                      |
| ---------------------------- | -------------------------------------------- |
| `README.md`                  | Project overview and production architecture |
| `docs/architecture.md`       | Detailed production architecture             |
| `docs/security-policy.md`    | Container and security controls              |
| `docs/ci-cd-runbook.md`      | CI/CD pipeline operations                    |
| `docs/deployment-runbook.md` | Production deployment and rollback           |
| `docs/dr-runbook.md`         | Disaster recovery and database recovery      |
| `docs/incident-response.md`  | Incident detection, response, and recovery   |

---

## 36. Final Incident Checklist

### Detection

* [ ] Incident confirmed
* [ ] Start time recorded
* [ ] Affected component identified
* [ ] Customer impact assessed

### Investigation

* [ ] ECS service state checked
* [ ] ECS task state checked
* [ ] ALB target health checked
* [ ] CloudWatch logs reviewed
* [ ] Recent deployment reviewed
* [ ] RDS status checked where applicable
* [ ] Security implications assessed

### Containment

* [ ] Unsafe deployment stopped if necessary
* [ ] Known-bad application revision identified
* [ ] Compromised credentials rotated if necessary
* [ ] Destructive changes avoided

### Recovery

* [ ] Application restored
* [ ] ECS services stable
* [ ] ALB targets healthy
* [ ] Database connectivity verified
* [ ] Required migrations verified
* [ ] Monitoring restored

### Closure

* [ ] Incident timeline recorded
* [ ] Root cause documented
* [ ] Customer impact documented
* [ ] Recovery action documented
* [ ] Preventive actions identified
* [ ] Follow-up engineering tasks created

---

## 37. Document Status

**Status:** Production documentation

**Environment:** AWS `eu-west-2`

**Last reviewed:** September 2026

**Owner:** Gambit Platform Engineering

**Related milestones:** 26.7 — Incident-Response Documentation
