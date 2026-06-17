variable "repos" {
  default = {
    "roboshop-cart"      = {}
    "roboshop-catalogue" = {}
  }
}

variable "env" {
  default = {
    "DEV"  = {}
    "QA"   = {}
    "UAT"  = {}
    "PROD" = {}
  }
}

locals {
  repos_with_envs = { for i, j in var.repos : i => { for x, y in var.env : "${i}_${x}" => { "env" = x, "app" = i } } }
}

output "x" {
  value = flatten([for a, b in local.repos_with_envs : values(b)])
}