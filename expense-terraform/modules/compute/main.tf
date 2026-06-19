# Create EC2 instances dynamically from the map
resource "aws_instance" "this" {
  for_each = var.instances

  ami    = "ami-0220d79f3f480ecf5"
  instance_type          = each.value.instance_type
  subnet_id              = var.subnet_ids[each.value.subnet_key] # Lookup the ID from the map!
  vpc_security_group_ids = [aws_security_group.common.id] # Simplified SG for example

  user_data = <<-EOF
              #!/bin/bash
              echo "Starting ${each.key} with user_data ${each.value.user_data}"
              # In real life, you'd run a script from S3 here.
              EOF

  tags = {
    Name = "${var.environment}-${each.key}"
    Role = each.key
  }
}

# Security group for all instances (simple example)
resource "aws_security_group" "common" {
  name_prefix = "${var.environment}-common-"
  vpc_id      = var.vpc_id # You'd pass this from networking too

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}