terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">1.12.0"
}

locals {
  labels = length(keys(var.labels)) >0 ? var.labels: {
    "env"=var.env_name
  }
}

resource "yandex_compute_instance" "vm" {
  count = var.instance_count

  name               = var.env_name == null ? "${var.instance_name}-${count.index}" : "${var.env_name}-${var.instance_name}-${count.index+1}"
  platform_id        = var.platform
  hostname           = var.env_name == null ? "${var.instance_name}-${count.index}" : "${var.env_name}-${var.instance_name}-${count.index+1}"
  zone               = element(var.subnet_zones, count.index)
  service_account_id = var.service_account_id
  scheduling_policy {
    preemptible = var.preemptible
  }
  
  resources {
    cores         = var.instance_cores
    memory        = var.instance_memory
    core_fraction = var.instance_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      type     = var.boot_disk_type
      size     = var.boot_disk_size
    }
  }

  network_interface {
    subnet_id  = element(var.subnet_ids, count.index)
    nat        = var.public_ip
    ip_address = var.known_internal_ip
    security_group_ids = var.security_group_ids
  }

  metadata = {
    for k, v in var.metadata : k => v
  }
  
  labels = {
    for k, v in local.labels : k => v
  }

  connection { # Данные для подключения к виртуальной машине для выполнения следующих provisioner'ов
    type = "ssh"
    user = "user"
    private_key = file(var.private_key)
    host = self.network_interface.0.nat_ip_address
  }

  provisioner "file" {
    source = "../compose/nginx.conf"
    destination = "/home/user/app/nginx.conf"
  }

  provisioner "file" {
    source = "../compose/default.conf"
    destination = "/home/user/app/default.conf"
  }

  provisioner "remote-exec" { # Устанавливаем docker на виртуальную машину. Данный способ мне нравится больше, так как установка через cloud-init не позволяет увидеть результаты установки и перейти к этапу запуска приложения с помощью docker
    inline = [
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "sudo tee /etc/apt/sources.list.d/docker.sources <<EOF",
      "Types: deb",
      "URIs: https://download.docker.com/linux/ubuntu",
      "Suites: $(. /etc/os-release && echo \"$${UBUNTU_CODENAME:-$VERSION_CODENAME}\")",
      "Components: stable",
      "Architectures: $(dpkg --print-architecture)",
      "Signed-By: /etc/apt/keyrings/docker.asc",
      "EOF",
      "sudo apt update",
      "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker user"
      ]
  }
}



