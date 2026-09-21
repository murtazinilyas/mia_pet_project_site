variable "env_name" {
  type    = string
  default = null
}

variable "instance_name" {
  type    = string
  default = "net"
}

variable "subnets" {
  type    = list(object({zone = string, cidr = list(string)}))
  default = [
    { zone = "ru-central1-a", cidr = ["10.0.1.0/24"]},
    ]
}

variable "allowed_cidr" {
  type = list(string)
  default = ["0.0.0.0/0"]
}

variable "ingress_ports" {
  type = map(string)
}