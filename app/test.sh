#!/bin/bash

echo "===== PROJECT ====="
pwd

echo
echo "===== DIRECTORIES ====="
find . -maxdepth 2 -type f | sort

echo
echo "===== DOCKER COMPOSE ====="
cat docker-compose.yml

echo
echo "===== FRONTEND DOCKERFILE ====="
cat frontend/Dockerfile 2>/dev/null || true

echo
echo "===== BACKEND FILES ====="
find backend -maxdepth 2 -type f -print 2>/dev/null | sort

echo
echo "===== WORKER FILES ====="
find worker -maxdepth 2 -type f -print 2>/dev/null | sort