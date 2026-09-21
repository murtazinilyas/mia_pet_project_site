module "project_vms" { # Создаем виртуальные машины
  source             = "./vm"
  env_name           = var.env_name
  network_id         = module.vpc.network_id
  subnet_zones       = module.vpc.zone
  subnet_ids         = module.vpc.subnet_id
  security_group_ids = module.vpc.security_group_ids
  instance_name      = "vm"
  instance_count     = 1
  public_ip          = true
  private_key         = var.private_key

  metadata = {
    user-data          = data.template_file.cloudinit.rendered
    serial-port-enable = 1
  }
  
}

data template_file "cloudinit" { # Создаем cloud-init файл
  template = file("./cloud-init.yml")

  vars = {
    username           = var.username
    ssh_public_key     = file(var.public_key)
  }
}
