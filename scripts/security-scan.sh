#!/usr/bin/env bash

set -euo pipefail

mkdir -p security-reports

echo "======================================"
echo " Gambit Security Scan"
echo "======================================"

echo
echo "[1/4] Scanning backend dependencies..."
python3 -m pip install --quiet pip-audit

python3 -m pip_audit \
    -r backend/requirements.txt \
    --format json \
    --output security-reports/backend-dependencies.json

python3 -m pip_audit \
    -r backend/requirements.txt

echo
echo "[2/4] Scanning frontend dependencies..."

if [ -f frontend/package-lock.json ]; then
    npm --prefix frontend audit --audit-level=high
else
    echo "ERROR: frontend/package-lock.json is missing."
    exit 1
fi

echo
echo "[3/4] Scanning Docker images..."

if ! command -v trivy >/dev/null 2>&1; then
    echo "ERROR: Trivy is not installed."
    echo "Install Trivy before running this script."
    exit 1
fi

docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep -E '^gambit-(backend|frontend):' \
    | while read -r image; do

        echo "Scanning ${image}"

        trivy image \
            --severity HIGH,CRITICAL \
            --exit-code 1 \
            --format table \
            "${image}"

    done

echo
echo "[4/4] Scanning repository for secrets..."

if command -v gitleaks >/dev/null 2>&1; then

    gitleaks detect \
        --source . \
        --config .gitleaks.toml \
        --redact \
        --exit-code 1

else

    echo "WARNING: Gitleaks is not installed locally."
    echo "CI will perform secret scanning."

fi

echo
echo "======================================"
echo " Security scan completed"
echo "======================================"
