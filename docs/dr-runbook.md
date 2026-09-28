# Gambit — Disaster Recovery Runbook

## Overview

This runbook defines the disaster recovery procedures for the Gambit production environment running in AWS `eu-west-2`.

It covers recovery of:

* Amazon RDS PostgreSQL
* ECS application services
* Application container versions
* Database schema
* Production application availability
* Monitoring and alerting

The objective is to provide a documented recovery procedure for infrastructure, application, and database failures.

---

# Table of Contents

1. [Production Recovery Architecture](#production-recovery-architecture)
2. [Current Recovery Capabilities](#current-recovery-capabilities)
3. [Recovery Objectives](#recovery-objectives)
4. [RDS Backup Strategy](#rds-backup-strategy)
5. [RDS Point-in-Time Recovery](#rds-point-in-time-recovery)
6. [RDS Snapshot Recovery](#rds-snapshot-recovery)
7. [PostgreSQL Recovery Validation](#postgresql-recovery-validation)
8. [ECS Application Recovery](#ecs-application-recovery)
9. [Application Rollback](#application-rollback)
10. [Database and Application Compatibility](#database-and-application-compatibility)
11. [Complete Production Recovery](#complete-production-recovery)
12. [Failure Scenarios](#failure-scenarios)
13. [Post-Recovery Validation](#post-recovery-validation)
14. [Monitoring After Recovery](#monitoring-after-recovery)
15. [Recovery Limitations](#recovery-limitations)
16. [Recovery Checklist](#recovery-checklist)

---

# Production Recovery Architecture

Gambit's production environment consists of:

```text
                         Internet
                            |
                            v
                 Application Load Balancer
                            |
                +-----------+-----------+
                |                       |
                v                       v
        ECS Backend Service      ECS Frontend Service
        Desired Count: 1        Desired Count: 1
                |
                v
        RDS PostgreSQL
        Private Subnets
```

Supporting services include:

```text
ECR
  |
  +-- gambit-backend
  +-- gambit-frontend

Secrets Manager
  |
  +-- RDS credentials

CloudWatch
  |
  +-- ECS logs
  +-- Production alarms

SNS
  |
  +-- Production alerts
```

Recovery therefore consists of restoring the affected layer while preserving dependencies between:

```text
Application
    |
    v
ECS
    |
    v
RDS
    |
    v
Database Schema
```

---

# Current Recovery Capabilities

The current Gambit production environment provides:

| Capability                  | Current State  |
| --------------------------- | -------------- |
| RDS automated backups       | Enabled        |
| RDS backup retention        | 1 day          |
| Point-in-time recovery      | Available      |
| Manual RDS snapshots        | Available      |
| RDS deletion protection     | Enabled        |
| RDS encryption              | Enabled        |
| RDS Multi-AZ                | Disabled       |
| ECS application rollback    | Available      |
| ECR image history           | Available      |
| ECS task-definition history | Available      |
| CloudWatch application logs | Enabled        |
| CloudWatch alarms           | Enabled        |
| SNS alerting                | Enabled        |
| Multi-region recovery       | Not configured |
| Production restore drill    | Not completed  |

---

# Recovery Objectives

## Recovery Point Objective

A formally measured production RPO has not been established.

The current RDS configuration provides automated backup and point-in-time recovery capability with a **1-day backup retention window**.

Therefore, the documented recovery capability should not be interpreted as a guaranteed RPO.

## Recovery Time Objective

A formally measured production RTO has not been established.

Actual recovery time depends on:

* failure type
* RDS restoration duration
* database size
* ECS startup time
* application validation
* DNS/load-balancer changes where applicable
* migration requirements
* operator intervention

RTO should be established after controlled recovery testing.

---

# RDS Backup Strategy

Gambit uses Amazon RDS PostgreSQL for production persistence.

Current configuration:

```text
Engine: PostgreSQL
Version: 16.15
Instance class: db.t4g.micro
Multi-AZ: Disabled
Publicly accessible: No
Deletion protection: Enabled
Backup retention: 1 day
Storage encryption: Enabled
```

## Automated Backups

RDS automated backups provide point-in-time recovery within the configured retention period.

The current backup retention period is:

```text
1 day
```

Verify the configuration:

```bash
aws rds describe-db-instances \
  --region eu-west-2 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `gambit`)].{Identifier:DBInstanceIdentifier,BackupRetention:BackupRetentionPeriod,MultiAZ:MultiAZ,DeletionProtection:DeletionProtection,Status:DBInstanceStatus}' \
  --output table
```

## Manual Snapshots

Manual snapshots can be used for longer-term recovery points.

List snapshots:

```bash
aws rds describe-db-snapshots \
  --region eu-west-2 \
  --query 'DBSnapshots[?contains(DBSnapshotIdentifier, `gambit`)].{Snapshot:DBSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime,Type:SnapshotType}' \
  --output table
```

A manual snapshot should be considered before significant destructive database changes where operationally appropriate.

---

# RDS Point-in-Time Recovery

Point-in-time recovery should be used when recovery to a specific time within the available backup window is required.

Typical scenarios include:

* accidental data deletion
* unintended destructive database changes
* application-induced data corruption
* recovery to a known-good point before an incident

## Step 1 — Identify the RDS Instance

```bash
aws rds describe-db-instances \
  --region eu-west-2 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `gambit`)].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address}' \
  --output table
```

Record the exact DB instance identifier.

## Step 2 — Identify the Recovery Window

Check available automated backups:

```bash
aws rds describe-db-instance-automated-backups \
  --region eu-west-2 \
  --query 'DBInstanceAutomatedBackups[?contains(DBInstanceArn, `gambit`)].{Status:Status,Latest:LatestRestorableTime,Earliest:EarliestRestorableTime}' \
  --output table
```

The selected recovery point must fall within the available recovery window.

## Step 3 — Restore to a New Instance

Point-in-time recovery creates a new RDS DB instance rather than modifying the existing instance in place.

Use the AWS console or an approved AWS CLI procedure to restore the selected recovery point.

Example structure:

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier <source-db-instance> \
  --target-db-instance-identifier <recovery-instance> \
  --restore-time <recovery-time> \
  --region eu-west-2
```

Do not execute the command using placeholder values.

## Step 4 — Wait for Availability

```bash
aws rds wait db-instance-available \
  --db-instance-identifier <recovery-instance> \
  --region eu-west-2
```

## Step 5 — Retrieve the Recovery Endpoint

```bash
aws rds describe-db-instances \
  --db-instance-identifier <recovery-instance> \
  --region eu-west-2 \
  --query 'DBInstances[0].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}'
```

## Step 6 — Validate the Database

Before directing the production application to the recovered database, validate:

* database availability
* expected database name
* expected tables
* expected schema revision
* expected recent data
* application connectivity
* required credentials

Do not immediately delete the original database.

Preserve the original instance while recovery validation is taking place unless there is a documented reason to do otherwise.

---

# RDS Snapshot Recovery

A manual snapshot can be restored when a known snapshot represents the desired recovery state.

## Step 1 — List Snapshots

```bash
aws rds describe-db-snapshots \
  --region eu-west-2 \
  --query 'DBSnapshots[?contains(DBSnapshotIdentifier, `gambit`)].{Snapshot:DBSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime}' \
  --output table
```

## Step 2 — Select the Recovery Snapshot

Confirm:

* snapshot status is `available`
* snapshot date/time
* snapshot source
* expected recovery point

## Step 3 — Restore

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <recovery-instance> \
  --db-snapshot-identifier <snapshot-identifier> \
  --region eu-west-2
```

## Step 4 — Wait for Availability

```bash
aws rds wait db-instance-available \
  --db-instance-identifier <recovery-instance> \
  --region eu-west-2
```

## Step 5 — Validate

Verify:

```bash
aws rds describe-db-instances \
  --db-instance-identifier <recovery-instance> \
  --region eu-west-2 \
  --query 'DBInstances[0].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}'
```

Then perform database and application validation before cutover.

---

# PostgreSQL Recovery Validation

After restoring a database, verify the schema before reconnecting the application.

## Schema Validation

The application uses Alembic.

Inspect migration history:

```bash
cd ~/Bandit/Gambit/app/backend

alembic history
```

The recovered database should contain the expected application schema.

Verify the migration state using the approved database access method.

Do not assume that the restored database contains the latest schema simply because the RDS restore succeeded.

## Application Tables

The Gambit application currently uses tables including:

```text
services
deployments
```

Additional application tables should be verified against the current SQLAlchemy models and Alembic migration history.

## Migration Compatibility

Confirm that:

```text
Recovered Database Schema
          |
          v
Application Version
```

are compatible before ECS services are redirected to the recovered database.

---

# ECS Application Recovery

If the application layer fails while the database remains healthy, recover the application independently.

## Check ECS Cluster

```bash
aws ecs describe-clusters \
  --clusters gambit-production \
  --region eu-west-2
```

## Check Services

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Name:serviceName,Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,TaskDefinition:taskDefinition}' \
  --output table
```

## Check Recent Tasks

```bash
aws ecs list-tasks \
  --cluster gambit-production \
  --desired-status STOPPED \
  --region eu-west-2
```

Inspect a failed task:

```bash
aws ecs describe-tasks \
  --cluster gambit-production \
  --tasks <task-arn> \
  --region eu-west-2 \
  --query 'tasks[].{StoppedReason:stoppedReason,Containers:containers[].{Name:name,ExitCode:exitCode,Reason:reason}}'
```

---

# Application Rollback

If a recent application deployment caused the failure and the database remains compatible, roll back the affected ECS service to a known-good task definition.

List revisions:

```bash
aws ecs list-task-definitions \
  --family-prefix gambit-production-backend \
  --region eu-west-2 \
  --sort DESC \
  --max-items 10
```

Inspect a revision:

```bash
aws ecs describe-task-definition \
  --task-definition <task-definition-arn> \
  --region eu-west-2 \
  --query 'taskDefinition.{Family:family,Revision:revision,Images:containerDefinitions[].image}'
```

Update the backend:

```bash
aws ecs update-service \
  --cluster gambit-production \
  --service gambit-production-backend \
  --task-definition <known-good-task-definition-arn> \
  --region eu-west-2
```

Wait for stability:

```bash
aws ecs wait services-stable \
  --cluster gambit-production \
  --services gambit-production-backend \
  --region eu-west-2
```

Repeat for the frontend if required.

## Important

An ECS rollback does **not** reverse an Alembic database migration.

Application rollback and database recovery must therefore be assessed independently.

---

# Database and Application Compatibility

Database recovery and application recovery must be performed in a compatible order.

A safe recovery sequence is:

```text
Identify failure
      |
      v
Determine whether database is affected
      |
      +---- No ----> Roll back/recover ECS application
      |
      |
     Yes
      |
      v
Identify recovery point
      |
      v
Restore database
      |
      v
Validate database
      |
      v
Confirm application/schema compatibility
      |
      v
Deploy compatible application revision
      |
      v
Validate production
```

Do not restore a database to an older schema while leaving an incompatible application revision running.

---

# Complete Production Recovery

A complete recovery may be required if both the application and database are affected.

## Phase 1 — Stabilize

1. Identify the incident.
2. Stop additional deployments.
3. Identify the last known-good application revision.
4. Identify the database recovery point.
5. Preserve relevant logs and operational evidence.

## Phase 2 — Recover Database

Depending on the incident:

* use PITR, or
* restore a manual RDS snapshot.

Wait until the restored database becomes available.

## Phase 3 — Validate Database

Confirm:

* connectivity
* expected schema
* expected migration state
* expected data
* database credentials
* security-group connectivity

## Phase 4 — Recover Application

Deploy or roll back to an application revision compatible with the recovered database.

## Phase 5 — Validate ECS

Confirm:

```text
Backend desired = 1
Backend running = 1

Frontend desired = 1
Frontend running = 1
```

Check task health and ECS deployment status.

## Phase 6 — Validate ALB

Verify target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region eu-west-2
```

Expected:

```text
healthy
```

## Phase 7 — Validate Application

Backend:

```bash
curl -fsS \
  http://gambit-production-alb-563168449.eu-west-2.elb.amazonaws.com/health
```

Information endpoint:

```bash
curl -fsS \
  http://gambit-production-alb-563168449.eu-west-2.elb.amazonaws.com/info
```

Frontend:

```bash
curl -I \
  http://gambit-production-alb-563168449.eu-west-2.elb.amazonaws.com/
```

## Phase 8 — Resume Normal Operations

After recovery:

* monitor CloudWatch logs
* monitor ECS services
* monitor ALB targets
* review CloudWatch alarms
* confirm SNS alerts
* document the incident
* identify follow-up actions

---

# Failure Scenarios

## Scenario 1 — ECS Task Failure

### Symptoms

* ECS task stops
* desired count remains higher than running count
* ALB target becomes unhealthy
* application becomes unavailable

### Response

1. Inspect ECS task stopped reason.
2. Review CloudWatch logs.
3. Check container image and environment configuration.
4. Check secrets.
5. Check database connectivity.
6. Redeploy or roll back to a known-good task definition.

---

## Scenario 2 — Failed Application Deployment

### Symptoms

* deployment completes but application is unhealthy
* ALB targets remain unhealthy
* application returns unexpected errors

### Response

1. Stop further deployments.
2. Identify the deployed task definition.
3. Identify the last known-good task definition.
4. Roll back the affected ECS service.
5. Validate application health.
6. Investigate the failed release.

---

## Scenario 3 — Accidental Database Data Change

### Symptoms

* unexpected data deletion
* incorrect records
* application-generated data corruption

### Response

1. Identify the approximate incident time.
2. Stop changes that could worsen the issue.
3. Determine whether the desired recovery point is within the automated backup window.
4. Use PITR when appropriate.
5. Otherwise evaluate the latest suitable manual snapshot.
6. Validate recovered data.
7. Determine application/database compatibility.
8. Perform controlled recovery.

---

## Scenario 4 — RDS Instance Failure

### Symptoms

* database unavailable
* ECS backend cannot connect
* database-dependent application operations fail

### Response

1. Check RDS status.
2. Check CloudWatch/RDS events.
3. Confirm security-group configuration.
4. Determine whether the issue is temporary or requires recovery.
5. If required, restore using the documented RDS recovery procedure.
6. Validate the recovered database.
7. Reconnect the application.
8. Verify `/health` and application functionality.

Because Multi-AZ is currently disabled, the environment does not have an automatic RDS standby failover configuration.

---

## Scenario 5 — AWS Regional Failure

The current Gambit deployment is regional and does not have a documented multi-region failover environment.

A complete `eu-west-2` regional failure therefore exceeds the currently implemented automated recovery capability.

In this scenario:

1. Confirm the regional scope of the incident.
2. Preserve available operational information.
3. Monitor AWS service status.
4. Determine whether recovery within the same region is possible.
5. If a regional recovery architecture is later implemented, follow that architecture's documented failover procedure.

---

# Post-Recovery Validation

After recovery, verify every major application layer.

## Infrastructure

```text
[ ] ECS cluster available
[ ] ECS backend service ACTIVE
[ ] ECS frontend service ACTIVE
[ ] Desired task counts restored
[ ] Running task counts restored
```

## Database

```text
[ ] RDS available
[ ] Database endpoint accessible
[ ] Database schema validated
[ ] Migration state validated
[ ] Expected data verified
[ ] Database remains private
```

## Application

```text
[ ] Backend container running
[ ] Frontend container running
[ ] /health succeeds
[ ] /info succeeds
[ ] Frontend responds
```

## Load Balancer

```text
[ ] Backend targets healthy
[ ] Frontend targets healthy
[ ] ALB responds
```

## Observability

```text
[ ] CloudWatch logs available
[ ] No unexplained application errors
[ ] CloudWatch alarms reviewed
[ ] SNS alerting operational
```

---

# Monitoring After Recovery

Monitor the environment closely after recovery.

Review ECS:

```bash
aws ecs describe-services \
  --cluster gambit-production \
  --services gambit-production-backend gambit-production-frontend \
  --region eu-west-2 \
  --query 'services[].{Name:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status}' \
  --output table
```

Review alarms:

```bash
aws cloudwatch describe-alarms \
  --region eu-west-2 \
  --query 'MetricAlarms[?contains(AlarmName, `gambit-production`)].{Name:AlarmName,State:StateValue,Reason:StateReason}' \
  --output table
```

Review logs:

```bash
aws logs tail /ecs/gambit-production \
  --region eu-west-2 \
  --since 30m
```

Continue monitoring until the application has demonstrated stable operation after recovery.

---

# Recovery Limitations

The current Gambit architecture has the following disaster-recovery limitations:

| Limitation                    | Impact                                                           |
| ----------------------------- | ---------------------------------------------------------------- |
| RDS backup retention is 1 day | Recovery window is limited                                       |
| RDS Multi-AZ is disabled      | No automatic database standby failover                           |
| Single ECS task per service   | No task-level redundancy                                         |
| No multi-region deployment    | No automated regional failover                                   |
| No production restore drill   | Recovery process has not been validated end-to-end in production |
| No formally measured RTO      | Recovery duration is not guaranteed                              |
| No formally measured RPO      | Data-loss tolerance is not formally established                  |
| HTTPS is not configured       | Current ALB traffic uses HTTP                                    |
| ECR scan-on-push is disabled  | CI provides the primary image vulnerability scanning gate        |

These limitations should be explicitly considered when describing Gambit's production resilience.

---

# Future DR Improvements

Potential future improvements include:

1. Increase RDS backup retention.
2. Enable RDS Multi-AZ.
3. Perform controlled RDS restore drills.
4. Establish and measure RTO/RPO.
5. Increase ECS desired count.
6. Configure ECS autoscaling.
7. Enable ECR image scanning.
8. Enforce ECR tag immutability.
9. Implement HTTPS/TLS.
10. Develop a multi-region recovery architecture if business requirements justify it.
11. Automate recovery validation.
12. Schedule periodic disaster-recovery exercises.

---

# Recovery Checklist

## Incident Identification

```text
[ ] Incident identified
[ ] Deployment activity stopped
[ ] Failure scope determined
[ ] Application impact assessed
[ ] Database impact assessed
```

## Database Recovery

```text
[ ] Recovery point identified
[ ] Automated backup availability checked
[ ] Snapshot availability checked
[ ] Recovery method selected
[ ] Database restored
[ ] Database validated
[ ] Schema validated
[ ] Application compatibility confirmed
```

## Application Recovery

```text
[ ] Known-good task definition identified
[ ] ECS service recovered
[ ] Running task count verified
[ ] ALB target health verified
[ ] Application endpoints verified
```

## Observability

```text
[ ] CloudWatch logs reviewed
[ ] CloudWatch alarms reviewed
[ ] SNS alerting reviewed
[ ] Post-recovery monitoring enabled
```

## Closure

```text
[ ] Application stable
[ ] Database stable
[ ] Incident documented
[ ] Recovery actions recorded
[ ] Root cause identified where possible
[ ] Follow-up actions created
[ ] DR documentation updated if required
```

---

# Related Documentation

* [`README.md`](../README.md)
* [`docs/architecture.md`](architecture.md)
* [`docs/cicd-runbook.md`](cicd-runbook.md)
* [`docs/deployment-runbook.md`](deployment-runbook.md)
* [`security/security-policy.md`](../security/security-policy.md)

---

# Document Status

**Milestone:** 26.6 — Disaster Recovery Documentation
**Environment:** Production
**AWS Region:** `eu-west-2`
**Status:** Production DR procedure documented
