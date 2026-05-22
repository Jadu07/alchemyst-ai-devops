# variables.tf — Input variables for the iii distributed deployment

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1" # Mumbai — closest to India
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "iii-inference"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "engine_instance_type" {
  description = "EC2 instance type for the iii engine / API gateway"
  type        = string
  default     = "t3.micro" # 1 GB RAM — just routes traffic
}

variable "caller_instance_type" {
  description = "EC2 instance type for the caller worker"
  type        = string
  default     = "t3.micro" # 1 GB RAM — lightweight Node.js
}

variable "inference_instance_type" {
  description = "EC2 instance type for the inference worker"
  type        = string
  default     = "t3.medium" # 4 GB RAM — needs memory for PyTorch + model
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the engine (bastion). Set to your IP."
  type        = string
  default     = "0.0.0.0/0" # Open for demo — restrict in production!
}

variable "repo_url" {
  description = "Public Git repo URL — worker VMs clone this to get the quickstart code"
  type        = string
  default     = "https://github.com/Jadu07/alchemyst-ai-devops"
}
