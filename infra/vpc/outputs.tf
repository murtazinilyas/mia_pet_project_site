output "network_id" {
  value = yandex_vpc_network.project_vpc.id
}

output "subnet_id" {
  value = yandex_vpc_subnet.project_subnet[*].id
}

output "zone" {
  value = yandex_vpc_subnet.project_subnet[*].zone
}

output "security_group_ids" {
  value       = [yandex_vpc_security_group.project_sg.id]
}

output "all_net" {
  value = yandex_vpc_network.project_vpc
}

output "all_subnet" {
  value = yandex_vpc_subnet.project_subnet[*]
}