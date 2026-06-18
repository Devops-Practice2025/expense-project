# 1. Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_config.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.environment}-vpc" }
}

# 2. Create Subnets using for_each on the incoming map
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.is_public

  tags = {
    Name = "${var.environment}-${each.key}"
    Tier = each.value.is_public ? "public" : "private"
  }
}

# 3. Internet Gateway (Only if there are public subnets)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment}-igw" }
}

# 4. Public Route Table (Associates only to public subnets)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate public route table only to subnets where is_public = true
resource "aws_route_table_association" "public" {
  for_each = { for k, v in var.subnets : k => v if v.is_public }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}