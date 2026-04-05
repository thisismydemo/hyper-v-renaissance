terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "= 1.2.1"
    }
  }

  backend "s3" {}
}
