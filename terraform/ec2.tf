# ec2.tf — EC2 Instances (Engine + 2 Workers)
# Provisions the three compute instances. Each instance uses a user-data script
# to automatically clone the repository, install dependencies, and start running.

# VM1: Engine / API Gateway (PUBLIC SUBNET)
# Acts as the central WebSocket hub and HTTP API. This is the only instance 
# that has a public IP and allows inbound internet traffic on port 3111.
resource "aws_instance" "engine" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.engine_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.engine.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = templatefile("${path.module}/../scripts/setup-engine.sh", {
    repo_url = var.repo_url
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-engine" }
}

# Elastic IP for the engine — survives stop/start, gives stable public IP
resource "aws_eip" "engine" {
  instance = aws_instance.engine.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-engine-eip" }
}

# VM2: Caller Worker (PRIVATE SUBNET)
# A TypeScript Node.js worker that bridges incoming HTTP requests to RPC calls.
# It runs in the private subnet and connects back to the engine via WebSocket.
resource "aws_instance" "caller_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.caller_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.worker.id]
  key_name               = aws_key_pair.deployer.key_name

  # templatefile injects the engine's private IP and repo URL into the script
  user_data = templatefile("${path.module}/../scripts/setup-caller-worker.sh", {
    engine_private_ip = aws_instance.engine.private_ip
    repo_url          = var.repo_url
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-caller-worker" }

  depends_on = [aws_instance.engine, aws_nat_gateway.main]
}

# VM3: Inference Worker (PRIVATE SUBNET)
# A Python worker running the SLM. Requires a larger instance size for memory.
# It runs in the private subnet and connects back to the engine via WebSocket.
resource "aws_instance" "inference_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.inference_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.worker.id]
  key_name               = aws_key_pair.deployer.key_name

  # templatefile injects the engine's private IP and repo URL into the script
  user_data = templatefile("${path.module}/../scripts/setup-inference-worker.sh", {
    engine_private_ip = aws_instance.engine.private_ip
    repo_url          = var.repo_url
  })

  root_block_device {
    volume_size = 30 # extra space for model download + pip packages
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-inference-worker" }

  depends_on = [aws_instance.engine, aws_nat_gateway.main]
}
