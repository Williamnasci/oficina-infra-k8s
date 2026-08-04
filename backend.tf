# Backend remoto compartilhado com oficina-infra-database (mesmo bucket, chave diferente).
# Bucket criado uma unica vez fora do Terraform (bootstrap manual).
terraform {
  backend "s3" {
    bucket       = "oficina-tfstate-778031418843"
    key          = "k8s/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
