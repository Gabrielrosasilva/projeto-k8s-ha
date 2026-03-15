terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-k8s"
    key    = "projeto-k8s-ha/terraform.tfstate"
    region = "sa-saopaulo-1"

    # Sintaxe correta para o Terraform 1.5.7
    endpoint                    = "https://grcz8lmkhuou.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}