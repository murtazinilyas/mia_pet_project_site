terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">1.12.0"
}

resource "yandex_vpc_network" "project_vpc" {
  name = var.env_name == null ? "${var.instance_name}" : "${var.env_name}-${var.instance_name}"
}

resource "yandex_vpc_subnet" "project_subnet" {
  count          = length(var.subnets)
  name           = var.env_name == null ? "${var.instance_name}-${var.subnets[count.index].zone}" : "${var.env_name}-${var.instance_name}-${var.subnets[count.index].zone}"
  zone           = var.subnets[count.index].zone
  network_id     = yandex_vpc_network.project_vpc.id
  v4_cidr_blocks = var.subnets[count.index].cidr
}

resource "yandex_vpc_security_group" "project_sg" {
  name       = var.env_name == null ? "${var.instance_name}-sg" : "${var.env_name}-${var.instance_name}-sg" 
  network_id = yandex_vpc_network.project_vpc.id

  egress { # Разрешаем весь исходящий трафик
    protocol          = "ANY"
    v4_cidr_blocks    = var.allowed_cidr
    description       = "Allow all outgoing traffic"
  }

  dynamic "ingress" { # Разрешаем входящий трафик по определенным портам
    for_each = var.ingress_ports
    content {
      protocol          = "TCP"
      port              = ingress.value
      v4_cidr_blocks    = var.allowed_cidr
      description       = ingress.key
    }
  }

  ingress { # Разрешаем входящий трафик внутри группы безопасности
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
}