<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >1.12.0 |

## Providers

| Name |
|------|
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) |

## Resources

| Name | Type |
|------|------|
| [yandex_vpc_network.project_vpc](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_network) | resource |
| [yandex_vpc_security_group.project_sg](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group) | resource |
| [yandex_vpc_subnet.project_subnet](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr"></a> [allowed\_cidr](#input\_allowed\_cidr) | n/a | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_env_name"></a> [env\_name](#input\_env\_name) | n/a | `string` | `null` | no |
| <a name="input_ingress_ports"></a> [ingress\_ports](#input\_ingress\_ports) | n/a | `map(string)` | n/a | yes |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | n/a | `string` | `"net"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | n/a | `list(object({zone = string, cidr = list(string)}))` | <pre>[<br/>  {<br/>    "cidr": [<br/>      "10.0.1.0/24"<br/>    ],<br/>    "zone": "ru-central1-a"<br/>  }<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_all_net"></a> [all\_net](#output\_all\_net) | n/a |
| <a name="output_all_subnet"></a> [all\_subnet](#output\_all\_subnet) | n/a |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | n/a |
| <a name="output_security_group_ids"></a> [security\_group\_ids](#output\_security\_group\_ids) | n/a |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | n/a |
| <a name="output_zone"></a> [zone](#output\_zone) | n/a |
<!-- END_TF_DOCS -->