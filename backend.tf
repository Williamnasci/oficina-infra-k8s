terraform {
  backend "s3" {
    bucket       = "oficina-tfstate-804680418945"
    key          = "k8s/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
