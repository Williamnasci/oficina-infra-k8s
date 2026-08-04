terraform {
  # >= 1.10.0 porque backend.tf usa use_lockfile (locking nativo do S3),
  # nao suportado em versoes anteriores.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0, < 6.0.0"
    }
  }
}
