terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    docker = {
      source = "kreuzwerker/docker"
    }    
  }
  required_version = ">1.12.0"

  backend "s3" { # Создаем backend для хранения состояния Terraform в S3
    profile = "default"
    region  = "ru-central1"

    bucket  = "mia-tfstate-bucket"
    key     = "ter_project/terraform.tfstate"
    encrypt = false

    use_lockfile = true

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true

    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
  }
}

provider "yandex" {
  cloud_id  = local.cloud_id
  folder_id = local.folder_id
}

provider "docker" { # Задаем точку подключения к remote docker context
  host      = "ssh://${var.username}@${module.project_vms.external_ip_address[0]}"
  ssh_opts  = ["-i", "${var.private_key}", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
}