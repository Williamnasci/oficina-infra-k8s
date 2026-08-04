#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/oficina-bootstrap.log) 2>&1

echo "== instalando dependencias =="
apt-get update -y
apt-get install -y docker.io curl unzip

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "== instalando aws cli v2 (nao disponivel via apt no Ubuntu 24.04) =="
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

echo "== instalando kubectl =="
KUBECTL_VERSION="$(curl -Ls https://dl.k8s.io/release/stable.txt)"
curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

echo "== instalando kind =="
curl -Lo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64"
chmod +x /usr/local/bin/kind

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "== gerando config do cluster kind =="
cat <<KINDCONFIG > /root/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: ${kind_api_server_port}
nodes:
- role: control-plane
  image: ${kind_node_image}
  extraPortMappings:
  - containerPort: 30080
    hostPort: ${app_node_port}
    protocol: TCP
KINDCONFIG

echo "== criando cluster kind (nome: ${cluster_name}) =="
kind create cluster --name "${cluster_name}" --config /root/kind-config.yaml --wait 180s

echo "== gerando kubeconfig externo (server = IP publico da EC2) =="
# apiServerAddress "0.0.0.0" faz o kind gravar "0.0.0.0" no kubeconfig (nao
# sempre 127.0.0.1) - troca qualquer um dos dois pelo IP publico real.
kind get kubeconfig --name "${cluster_name}" | sed -E "s#(https://)(127\.0\.0\.1|0\.0\.0\.0)(:)#\1$PUBLIC_IP\3#" > /root/kubeconfig

echo "== publicando kubeconfig no Secrets Manager =="
if aws secretsmanager describe-secret --region "${aws_region}" --secret-id oficina/k8s/kubeconfig >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --region "${aws_region}" \
    --secret-id oficina/k8s/kubeconfig \
    --secret-string "file:///root/kubeconfig"
else
  aws secretsmanager create-secret \
    --region "${aws_region}" \
    --name oficina/k8s/kubeconfig \
    --description "Kubeconfig externo do cluster Kind (oficina-infra-k8s)" \
    --secret-string "file:///root/kubeconfig"
fi

touch /root/bootstrap-complete
echo "== bootstrap concluido =="
