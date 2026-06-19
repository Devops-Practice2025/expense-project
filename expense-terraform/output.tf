output "vpc_id" {
  value = module.vpc.vpc_id
}

# Shows you the map of all subnets -> IDs
output "subnet_id_map" {
  value = module.vpc.subnet_ids
}

# Shows you the map of instances -> Private IPs
output "instance_ip_map" {
  value = { for k, v in module.compute.this : k => v.private_ip } # You need to export this in compute outputs
}