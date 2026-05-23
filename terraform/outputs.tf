# outputs.tf — Values printed after `terraform apply`

output "api_endpoint" {
  description = "The public URL for the inference JSON API"
  value       = "http://${aws_eip.engine.public_ip}:3111/v1/chat/completions"
}

output "engine_public_ip" {
  description = "Engine/API gateway public IP (for SSH and API access)"
  value       = aws_eip.engine.public_ip
}

output "engine_private_ip" {
  description = "Engine private IP (workers connect to this)"
  value       = aws_instance.engine.private_ip
}

output "caller_worker_private_ip" {
  description = "Caller worker private IP"
  value       = aws_instance.caller_worker.private_ip
}

output "inference_worker_private_ip" {
  description = "Inference worker private IP"
  value       = aws_instance.inference_worker.private_ip
}

output "ssh_command_engine" {
  description = "SSH into the engine VM"
  value       = "ssh -i terraform/${var.project_name}-key.pem ubuntu@${aws_eip.engine.public_ip}"
}

output "ssh_command_caller_worker" {
  description = "SSH into caller worker (via engine as bastion/jump host)"
  value       = "ssh-add terraform/${var.project_name}-key.pem 2>/dev/null; ssh -i terraform/${var.project_name}-key.pem -J ubuntu@${aws_eip.engine.public_ip} ubuntu@${aws_instance.caller_worker.private_ip}"
}

output "ssh_command_inference_worker" {
  description = "SSH into inference worker (via engine as bastion/jump host)"
  value       = "ssh-add terraform/${var.project_name}-key.pem 2>/dev/null; ssh -i terraform/${var.project_name}-key.pem -J ubuntu@${aws_eip.engine.public_ip} ubuntu@${aws_instance.inference_worker.private_ip}"
}

output "curl_test_command" {
  description = "Test the API with this curl command"
  value       = <<-EOT
    curl -X POST http://${aws_eip.engine.public_ip}:3111/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"messages": [{"role": "user", "content": "Hello, how are you?"}]}'
  EOT
}
