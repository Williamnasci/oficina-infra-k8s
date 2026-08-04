data "aws_caller_identity" "current" {}

resource "aws_iam_role" "cluster_host" {
  name = "${var.cluster_name}-cluster-host-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Permite acesso via SSM Session Manager em vez de SSH — sem chave para gerenciar/vazar.
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.cluster_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "publish_kubeconfig" {
  name = "publish-kubeconfig-secret"
  role = aws_iam_role.cluster_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:CreateSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:oficina/k8s/*"
    }]
  })
}

resource "aws_iam_instance_profile" "cluster_host" {
  name = "${var.cluster_name}-cluster-host-profile"
  role = aws_iam_role.cluster_host.name
}
