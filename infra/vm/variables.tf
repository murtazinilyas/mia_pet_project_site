variable "env_name" {
  type    = string
  default = null
}

variable "network_id" {
  type = string
}

variable "subnet_zones" {
  type = list(string)
}

variable "image_id" {
  type = string
  default = "fd8n7088reip5bg4dn09"
}

variable "subnet_ids" {
  type = list(string)
}
variable "instance_name" {
  type    = string
  default = "mia_vm"
}

variable "platform" {
   type          = string
   default       = "standard-v4a"
   validation {
     condition = contains(["standard-v1", "standard-v2", "standard-v3", "standard-v4a"], var.platform)
     error_message = "Invalid platform provided."
   }
}

variable "service_account_id" {
  type    = string
  default = null
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "instance_cores" {
  type    = number
  default = 2
}

variable "instance_memory" {
  type    = number
  default = 1
}

variable "instance_core_fraction" {
  type    = number
  default = 20
}

variable "boot_disk_type" {
  type    = string
  default = "network-hdd"
}

variable "boot_disk_size" {
  type    = number
  default = 10
}

variable "public_ip" {
  type    = bool
  default = false
}

variable "known_internal_ip" {
  default = ""
}

variable "preemptible" {
  type = bool
  default = true
}

variable "metadata" {
  description = "for dynamic block 'metadata' "
  type        = map(string)
}

variable "security_group_ids" {
  type = list(string)
  default = []
}

variable "labels" {
  type        = map(string)
  default = {}
}

variable "private_key" {
  type    = string
}