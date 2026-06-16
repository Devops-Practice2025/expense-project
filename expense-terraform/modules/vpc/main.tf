# Key attributes explained:
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr        # e.g. 10.0.0.0/16 — the IP space
  enable_dns_support   = true                # EC2 instances can resolve hostnames
  enable_dns_hostnames = true                # gives .internal DNS to instances
}

resource "aws_subnet" "publicsubnet" {

for_each = var.subnets
vpc_id = aws_vpc.main.id
cidr_block = each.value.cidr_block
availability_zone = each.value.



}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id             # Elastic IP — static public IP for NAT
  subnet_id     = aws_subnet.public[0].id   # NAT must live in PUBLIC subnet
  # Private EC2 uses NAT to reach internet (for yum install, git clone etc.)
}