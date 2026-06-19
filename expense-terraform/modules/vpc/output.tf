output "vpc_id" {
  value = aws_vpc.main.id
}

# Returns the full map of subnet IDs keyed by their names
output "subnet_ids" {
  value = { for k, v in aws_subnet.this : k => v.id }
}

# Returns only public subnet IDs
output "public_subnet_ids" {
  value = { for k, v in aws_subnet.this : k => v.id if var.subnets[k].is_public }
}

# Returns only private subnet IDs
output "private_subnet_ids" {
  value = { for k, v in aws_subnet.this : k => v.id if !var.subnets[k].is_public }
}