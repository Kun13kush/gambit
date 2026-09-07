# Gambit Container Security Policy

## Vulnerability thresholds

CI must fail for:

- CRITICAL vulnerabilities
- HIGH vulnerabilities
- Confirmed leaked secrets
- Critical Dockerfile misconfigurations

MEDIUM and LOW vulnerabilities are reported but do not currently block CI.

## Container security

Application containers must:

- Run as a non-root user
- Avoid unnecessary Linux capabilities
- Avoid privileged mode
- Avoid embedding secrets
- Use controlled/pinned base images where practical

## Dependency security

Backend:

- Python dependencies must be explicitly version controlled.
- Known HIGH/CRITICAL vulnerabilities must be investigated before release.

Frontend:

- package-lock.json must remain committed.
- HIGH/CRITICAL npm vulnerabilities should block CI.

## Secret security

Secrets must never be committed to Git.

Examples:

- passwords
- API keys
- access tokens
- private keys
- database credentials
- cloud credentials
