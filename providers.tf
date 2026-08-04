provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "oficina-tech-challenge"
      Phase     = "fase-3"
      ManagedBy = "terraform"
      Repo      = "oficina-infra-k8s"
    }
  }
}
