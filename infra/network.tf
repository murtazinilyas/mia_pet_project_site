module "vpc" { # Создаем сеть, подсеть и группу безопасности
  source   = "./vpc"
  env_name = var.env_name
  ingress_ports = var.ingress_ports
}
