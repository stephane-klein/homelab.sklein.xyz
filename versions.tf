terraform {
  required_version = ">= 1.6.0"

  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    netbird = {
      source  = "registry.terraform.io/netbirdio/netbird"
      version = "~> 0.0.9"
    }
  }
}
