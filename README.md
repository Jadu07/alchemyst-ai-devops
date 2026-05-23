# Alchemyst AI - DevOps Internship Assignment

This repository contains the infrastructure-as-code (Terraform) and deployment scripts to deploy a distributed AI inference pipeline on AWS. The system is distributed across three virtual machines running inside an AWS VPC.

## Architecture

<img width="1122" height="1402" alt="image" src="https://github.com/user-attachments/assets/58da9a8e-040e-439a-8ab0-75181cd5fc8c" />

*Note: The Engine sits in the public subnet to receive HTTP requests. It routes these requests via RPC to the Caller Worker in the private subnet, which then triggers the Inference Worker (also in the private subnet) to process the PyTorch model.*

## Deployment Instructions (From Scratch)

**Prerequisites:**
- AWS CLI configured with your credentials
- Terraform installed

**Steps:**
1. **Clone Repository:**
   ```bash
   git clone https://github.com/Jadu07/alchemyst-ai-devops.git
   ```
2. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```
3. **Deploy the Infrastructure:**
   ```bash
   terraform apply -auto-approve
   ```
   *Terraform creates a VPC, subnets, a NAT Gateway, and security groups, and then sets up three EC2 instances. Each instance runs a startup script that clones the code repository, installs needed tools like Node.js and Python, creates a large swap file to prevent memory issues, and starts the worker processes in the background.*
4. **Wait for Model Loading:** The `t3.micro` instance has limited RAM. The Python worker uses an 8GB swap file to load the `gemma-3-270m` model. Wait approximately 20-30 minutes for the model to fully load into memory before sending API requests.
5. **Get API Endpoint:** Terraform will output the `api_endpoint` URL.

## API Usage

**Request:**
```bash
curl -X POST http://<ENGINE_PUBLIC_IP>:3111/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello, how are you?"}]}'
```

**Sample Response:**
```json
{
  "result": "I am an AI, I am doing fine. How can I help you today?",
  "success": "You've connected two workers and they're interoperating seamlessly, now let's add a few more workers to expand this project's functionality."
}
```

## How to Make It Ready for Production

Before real users use this system, we need to make it safer and more reliable:
- **Use Containers (Docker):** Right now, we start the workers manually using simple shell scripts. For production, we should package them inside Docker containers. We can then use an orchestrator like Kubernetes (AWS EKS) to run them. If a worker crashes, Kubernetes will automatically restart it (self-healing).
- **Better Security (ALB & WAF):** The API Gateway's security group currently accepts traffic from `0.0.0.0/0`. This should be restricted to a Load Balancer (ALB) equipped with an AWS WAF to prevent DDoS attacks. Additionally, the private workers could use VPC Endpoints instead of a NAT Gateway to strictly control outbound access to the HuggingFace Hub.
- **Hide Secrets (Secrets Manager):** The SSH keys and GitHub URLs should be securely injected using AWS Secrets Manager or Parameter Store rather than plain-text variables.

## How to Handle a 100x Larger AI Model

If we want to use a massive AI model (e.g., 70 billion parameters), we have to change the architecture:
- **Use Powerful GPUs:** Right now, we are using a tiny `t3.micro` CPU server and saving data to the hard drive swap space because we don't have enough RAM. A huge model requires specialized servers (like AWS `g5` instances) with dedicated graphics cards (GPUs) and high VRAM to run efficiently.
- The basic HuggingFace `transformers` python script would crash under heavy load. We would need to replace it with a highly optimized inference server like **vLLM** or **Text Generation Inference (TGI)**. These frameworks implement continuous batching, PagedAttention, and Tensor Parallelism, which are strictly required to efficiently serve massive models across multiple GPUs.

