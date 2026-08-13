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

IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

if [ -z "$PUBLIC_IP" ]; then
  echo "FATAL: could not resolve public IP via IMDSv2" >&2
  exit 1
fi

echo "== gerando config do cluster kind =="
# certSANs precisa incluir o IP publico, senao o certificado do apiserver so
# valida para os enderecos internos do Kind (10.96.0.1, IP do container, etc)
# e qualquer kubectl externo falha na verificacao TLS mesmo conseguindo conectar.
cat <<KINDCONFIG > /root/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: ${kind_api_server_port}
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  apiServer:
    certSANs:
    - "$PUBLIC_IP"
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

echo "== gerando kubeconfig (server = IP publico da EC2) =="
# apiServerAddress "0.0.0.0" faz o kind gravar "0.0.0.0" no kubeconfig (nao
# sempre 127.0.0.1) - troca qualquer um dos dois pelo IP publico real. O
# certificado do apiserver so tem SAN para 10.96.0.1, o IP interno do
# container e o IP publico (ver certSANs acima) - nem 0.0.0.0 nem 127.0.0.1
# validam, entao esse kubeconfig com IP publico e usado tanto local (metrics-
# server, abaixo) quanto externamente, em vez de gerar dois kubeconfigs.
kind get kubeconfig --name "${cluster_name}" | sed -E "s#(https://)(127\.0\.0\.1|0\.0\.0\.0)(:)#\1$PUBLIC_IP\3#" > /root/kubeconfig

echo "== instalando metrics-server (necessario para o HPA ler CPU/memoria reais) =="
kubectl --kubeconfig /root/kubeconfig apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Kind usa certificados de kubelet self-signed que o metrics-server nao valida
# por padrao - sem isso ele fica em CrashLoopBackOff e o HPA nunca sai do
# estado "unknown" (nao consegue ler metricas reais de CPU/memoria).
kubectl --kubeconfig /root/kubeconfig patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl --kubeconfig /root/kubeconfig rollout status deployment/metrics-server -n kube-system --timeout=120s

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
