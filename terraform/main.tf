# main.tf — VPC, Networking, and Security Groups
# Provisions the core network infrastructure, including a custom VPC, public 
# and private subnets, and the necessary gateways for internet routing.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source: latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu publisher)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC — isolated network
# Creates the virtual private cloud that isolates our infrastructure.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # needed for internal DNS resolution
  enable_dns_hostnames = true # needed for public DNS names on instances

  tags = { Name = "${var.project_name}-vpc" }
}

# Subnets — one public (engine), one private (workers)
# The public subnet assigns public IPs for the engine. The private subnet 
# keeps the workers hidden from the internet.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # instances here get public IPs automatically

  tags = { Name = "${var.project_name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  # NO map_public_ip_on_launch — private by design

  tags = { Name = "${var.project_name}-private" }
}

# Internet Gateway — public subnet internet access
# Allows instances in the public subnet to communicate with the outside world.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# NAT Gateway — private subnet outbound internet
# Allows workers in the private subnet to download npm/pip packages during setup, 
# without exposing them to inbound internet traffic.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id # NAT lives in public subnet

  tags       = { Name = "${var.project_name}-nat" }
  depends_on = [aws_internet_gateway.main]
}

# Route Tables

# Public route table: 0.0.0.0/0 → Internet Gateway (direct internet)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private route table: 0.0.0.0/0 → NAT Gateway (outbound only, no inbound)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Groups
# Per-VM firewall rules. The engine allows external HTTP traffic (3111), while 
# the workers strictly block all internet ingress and only allow internal VPC traffic.

# Engine / API Gateway SG
# WHY: only port 3111 (HTTP API) is open to the world.
#       Port 49134 (WebSocket for workers) is only open within the VPC.
#       Port 22 (SSH) is open for management.
resource "aws_security_group" "engine" {
  name        = "${var.project_name}-engine-sg"
  description = "Engine/API gateway - HTTP 3111 public, WS 49134 VPC-only"
  vpc_id      = aws_vpc.main.id

  # SSH access (bastion)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # HTTP API — the ONLY public-facing port
  ingress {
    description = "iii HTTP API"
    from_port   = 3111
    to_port     = 3111
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WebSocket for worker connections — VPC internal ONLY
  ingress {
    description = "iii Engine WebSocket (workers connect here)"
    from_port   = 49134
    to_port     = 49134
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-engine-sg" }
}

# Worker SG — completely private, no public ports
# WHY: workers should NEVER be reachable from the internet
resource "aws_security_group" "worker" {
  name        = "${var.project_name}-worker-sg"
  description = "Workers - no public access, only VPC internal"
  vpc_id      = aws_vpc.main.id

  # SSH only from engine (bastion hop)
  ingress {
    description     = "SSH from engine (bastion)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.engine.id]
  }

  # Allow all traffic within the VPC (workers ↔ engine communication)
  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound (for apt, pip, npm, model download via NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-worker-sg" }
}

# SSH Key Pair — auto-generated
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Save private key locally for SSH access
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}
