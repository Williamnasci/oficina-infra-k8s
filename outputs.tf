output "instance_id" {
  description = "ID da instância EC2 que hospeda o cluster Kind."
  value       = aws_instance.cluster_host.id
}

output "public_ip" {
  description = "IP público da EC2 — usar em oficina-infra-database (allowed_cidr_blocks) e como alvo de integração do API Gateway."
  value       = aws_instance.cluster_host.public_ip
}

output "app_nodeport_url" {
  description = "URL base da aplicação via NodePort (alvo de integração HTTP do API Gateway — ver ADR-0004 no oficina-api)."
  value       = "http://${aws_instance.cluster_host.public_ip}:${var.app_node_port}"
}

output "kubeconfig_secret_name" {
  description = "Nome do segredo no Secrets Manager onde o user_data publica o kubeconfig externo do cluster."
  value       = "oficina/k8s/kubeconfig"
}

output "security_group_id" {
  description = "ID do security group da EC2."
  value       = aws_security_group.cluster_host.id
}
