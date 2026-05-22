#!/bin/bash
# setup-engine.sh — Clones repo, installs iii engine, and starts it via nohup
# Injects ${repo_url} from Terraform
set -euo pipefail
exec > /var/log/setup-engine.log 2>&1

REPO_URL="${repo_url}"

echo "=== [1/6] System update ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "=== [2/6] Install Node.js 20, Git ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git jq

echo "=== [3/6] Install iii CLI ==="
curl -fsSL https://install.iii.dev/iii/main/install.sh | bash -

echo "=== [4/6] Clone project repo ==="
git clone "$REPO_URL" /opt/project
ENGINE_DIR=/opt/project/quickstart

echo "=== [5/6] Set permissions ==="
chown -R ubuntu:ubuntu /opt/project

echo "=== [6/6] Start iii engine in background ==="
cd $ENGINE_DIR
export NODE_ENV=production

nohup /root/.iii/bin/iii dev > /var/log/iii-engine-app.log 2>&1 &

echo "=== Engine setup complete ==="
