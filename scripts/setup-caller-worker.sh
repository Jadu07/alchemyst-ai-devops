#!/bin/bash
# setup-caller-worker.sh — Clones repo and starts Caller Worker via nohup
# Injects ${engine_private_ip} and ${repo_url} from Terraform
set -euo pipefail
exec > /var/log/setup-caller-worker.log 2>&1

ENGINE_IP="${engine_private_ip}"
REPO_URL="${repo_url}"

echo "=== [1/6] System update ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "=== [2/6] Install Node.js 20 + Git ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git
echo "Node.js $(node --version) | npm $(npm --version)"

echo "=== [3/6] Clone project repo ==="
git clone "$REPO_URL" /opt/project
WORKER_DIR=/opt/project/quickstart/workers/caller-worker

echo "=== [4/6] Install npm dependencies ==="
cd "$WORKER_DIR"
npm install

chown -R ubuntu:ubuntu /opt/project

echo "=== [5/5] Start caller worker in background ==="
cd $WORKER_DIR
export III_URL="ws://$ENGINE_IP:49134"
export NODE_ENV="production"
nohup npx tsx src/worker.ts > /var/log/caller-worker-app.log 2>&1 &

echo "=== Caller worker setup complete ==="
echo "Worker dir: $WORKER_DIR"
echo "Engine:     ws://$ENGINE_IP:49134"
