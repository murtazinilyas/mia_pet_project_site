###cloud vars
variable "public_key" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
  description = "Path to public key"
}

variable "private_key" {
  type    = string
  default = "~/.ssh/id_ed25519"
  description = "Path to private key"
}

variable "username" {
  type    = string
  default = "user"
  description = "Username"
}

variable "ingress_ports" {
  type = map(string)
  default = {
    "SSH access"   = "22",
    "HTTP access" = "80"
    "HTTPS access" = "443"
  }
  description = "Ingress ports."
}

variable "path_to_app" {
  type        = string
  default     = "/home/van/site/compose"
  description = "Path to app directory"
}

variable "env_name" {
  type        = string
  default     = "mia-project"
  description = "Environment name"
}