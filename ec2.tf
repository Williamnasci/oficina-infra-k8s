data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "cluster_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.cluster_host.id]
  iam_instance_profile   = data.aws_iam_instance_profile.cluster_host.name

  associate_public_ip_address = true

  root_block_device {
    volume_size = 20 # dentro dos 30GB gratuitos de EBS do Free Tier
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    cluster_name         = var.cluster_name
    kind_node_image      = var.kind_node_image
    kind_api_server_port = var.kind_api_server_port
    app_node_port        = var.app_node_port
    aws_region           = var.aws_region
  })
  user_data_replace_on_change = true

  # data.aws_ami.ubuntu usa most_recent = true, que resolve para uma AMI diferente
  # sempre que a Canonical publica uma nova build - sem isso, qualquer terraform
  # apply futuro (inclusive o job automatico de CI/CD em push para main) pode
  # substituir a instancia de forma inesperada so por causa de uma AMI mais nova,
  # mesmo sem nenhuma mudanca de configuracao real. A AMI mais recente ainda e
  # usada na criacao inicial; depois disso, fica congelada.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-host"
  }
}
