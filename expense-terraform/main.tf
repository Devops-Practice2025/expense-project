# main.tf

# 1. Call the VPC module, passing the maps from tfvars
module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
  vpc_config  = var.vpc_config
  subnets     = var.subnets
}

# 2. Call the Compute module, passing the instance map 
#    AND the subnet_ids output from the VPC module
module "compute" {
  source = "./modules/compute"

  environment = var.environment
  instances   = var.instances
  subnet_ids  = module.vpc.subnet_ids # Passing the MAP of subnet IDs
  vpc_id      = module.vpc.vpc_id
}