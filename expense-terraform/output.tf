output "vpc_id" {
  value = module.vpc.vpc_id
}

# Shows you the map of all subnets -> IDs
output "subnet_id_map" {
  value = module.vpc.subnet_ids
}

# Shows you the map of instances -> Private IPs
output "instance_private_ips" {
  value = { for k, v in module.compute.instances : k => v.private_ip }
}