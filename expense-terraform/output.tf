output "vpc_id" {
  value = module.networking.vpc_id
}

# Shows you the map of all subnets -> IDs
output "subnet_id_map" {
  value = module.networking.subnet_ids
}

