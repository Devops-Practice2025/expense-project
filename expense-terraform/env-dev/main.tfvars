# terraform.tfvars
environment = "dev"
project     = "expense"

# ----- VPC CONFIG MAP -----
vpc_config = {
  cidr_block = "10.0.0.0/16"
}

# ----- SUBNET MAP (Keyed by name) -----
subnets = {
  "public-1a" = {
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    is_public         = true
  }
  "public-1b" = {
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    is_public         = true
  }
  "private-app-1a" = {
    cidr_block        = "10.0.10.0/24"
    availability_zone = "us-east-1a"
    is_public         = false
  }
  "private-app-1b" = {
    cidr_block        = "10.0.11.0/24"
    availability_zone = "us-east-1b"
    is_public         = false
  }
  "private-db-1a" = {
    cidr_block        = "10.0.20.0/24"
    availability_zone = "us-east-1a"
    is_public         = false
  }
  "private-db-1b" = {
    cidr_block        = "10.0.21.0/24"
    availability_zone = "us-east-1b"
    is_public         = false
  }
}

# ----- EC2 INSTANCES MAP -----
instances = {
  "bastion" = {
    instance_type = "t3.micro"
    subnet_key    = "public-1a"
    user_data     = "bastion.sh"
  }
  "frontend" = {
    instance_type = "t3.micro"
    subnet_key    = "public-1b"   # Or private, depending on your design
    user_data     = "frontend.sh"
  }
  "backend" = {
    instance_type = "t3.micro"
    subnet_key    = "private-app-1a"
    user_data     = "backend.sh"
  }
}

# ----- SECURITY GROUP RULES MAP (Optional advanced) -----
sg_rules = {
  "allow_ssh" = {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    target_sg   = "bastion"
  }
  "allow_http" = {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    target_sg   = "frontend"
  }
}