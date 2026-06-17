module "networking" {
source = "./modules/vpc"
vpc_cidr = var.vpc_cidr
subnets = var.subnets  
}