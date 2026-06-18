# main.tf

# 1. Call the Networking module, passing the maps from tfvars
module "networking" {
  source = "./modules/networking"

  environment = var.environment
  vpc_config  = var.vpc_config
  subnets     = var.subnets
}

# 2. Call the Compute module, passing the instance map 
#    AND the subnet_ids output from the networking module
