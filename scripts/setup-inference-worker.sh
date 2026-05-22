#!/bin/bash
# setup-inference-worker.sh — Clones repo and starts Inference Worker via nohup
# Injects ${engine_private_ip} and ${repo_url} from Terraform
set -euo pipefail
exec > /var/log/setup-inference-worker.log 2>&1

ENGINE_IP="${engine_private_ip}"
REPO_URL="${repo_url}"

echo "=== [1/6] System update ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "=== [2/6] Install Python 3.11 + Git ==="
apt-get install -y python3.11 python3.11-venv python3-pip git

echo "=== [3/6] Clone project repo ==="
git clone "$REPO_URL" /opt/project
WORKER_DIR=/opt/project/quickstart/workers/inference-worker

echo "=== [4/6] Install Python dependencies ==="
python3.11 -m venv /opt/inference-venv
source /opt/inference-venv/bin/activate
pip install --upgrade pip
pip install -r "$WORKER_DIR/requirements.txt"

chown -R ubuntu:ubuntu /opt/project /opt/inference-venv

echo "=== [5/5] Start inference worker in background ==="
cd $WORKER_DIR
export III_URL="ws://$ENGINE_IP:49134"
export HF_HOME="/opt/inference-venv/.cache/huggingface"
nohup /opt/inference-venv/bin/python inference_worker.py > /var/log/inference-worker-app.log 2>&1 &

echo "=== Inference worker setup complete ==="
echo "Worker dir: $WORKER_DIR"
echo "Engine:     ws://$ENGINE_IP:49134"
