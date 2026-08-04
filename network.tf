data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "cluster_host" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EC2 hospedando o cluster Kind (oficina-infra-k8s)"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_allowed_cidrs" {
  for_each = toset(var.ssh_allowed_cidr_blocks)

  security_group_id = aws_security_group.cluster_host.id
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH — nao usado por padrao; acesso operacional real e via SSM Session Manager"
}

resource "aws_vpc_security_group_ingress_rule" "app_nodeport_from_allowed_cidrs" {
  for_each = toset(var.app_allowed_cidr_blocks)

  security_group_id = aws_security_group.cluster_host.id
  cidr_ipv4         = each.value
  from_port         = var.app_node_port
  to_port           = var.app_node_port
  ip_protocol       = "tcp"
  description       = "NodePort da aplicacao — alvo de integracao do API Gateway (ver ADR-0004 no oficina-api)"
}

resource "aws_vpc_security_group_ingress_rule" "kube_api_from_allowed_cidrs" {
  for_each = toset(var.app_allowed_cidr_blocks)

  security_group_id = aws_security_group.cluster_host.id
  cidr_ipv4         = each.value
  from_port         = var.kind_api_server_port
  to_port           = var.kind_api_server_port
  ip_protocol       = "tcp"
  description       = "API server do Kind — usado pela pipeline de CI/CD do oficina-api (kubectl remoto)"
}
