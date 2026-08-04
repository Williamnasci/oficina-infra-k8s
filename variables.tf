variable "aws_region" {
  description = "Região AWS. Fixa em us-east-2 por decisão de projeto (ver docs/rfc/0001-escolha-da-nuvem.md no oficina-api)."
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "Tipo da instância EC2. t3.micro é elegível ao Free Tier (750h/mês nos primeiros 12 meses)."
  type        = string
  default     = "t3.micro"
}

variable "cluster_name" {
  description = "Nome do cluster Kind."
  type        = string
  default     = "oficina"
}

variable "kind_node_image" {
  description = "Imagem do node do Kind. Fixar uma versão evita quebra silenciosa se a tag 'latest' mudar."
  type        = string
  default     = "kindest/node:v1.31.0"
}

variable "kind_api_server_port" {
  description = "Porta em que o API server do Kind fica exposto no host (usada no kubeconfig gerado)."
  type        = number
  default     = 6443
}

variable "app_node_port" {
  description = "NodePort em que o Service da aplicação (oficina-api) é exposto — precisa bater com k8s/05-api-service.yaml no oficina-api."
  type        = number
  default     = 30080
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDRs autorizados a conectar via SSH (porta 22) na instância. Vazio por padrão (fail-closed)."
  type        = list(string)
  default     = []
}

variable "app_allowed_cidr_blocks" {
  description = "CIDRs autorizados a alcançar o NodePort da aplicação e a porta do API server do Kind. 0.0.0.0/0 é aceitável aqui porque o tráfego real do cliente final passa pelo API Gateway, não direto nesta porta — mas o valor é explícito, não implícito."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
