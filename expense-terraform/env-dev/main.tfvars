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
  "private-app-1a" = {
    cidr_block        = "10.0.10.0/24"
    availability_zone = "us-east-1a"
    is_public         = false
  }

  "private-db-1a" = {
    cidr_block        = "10.0.20.0/24"
    availability_zone = "us-east-1a"
    is_public         = false
  }

}

# ----- EC2 INSTANCES MAP -----
instances = {
  "frontend" = {
    instance_type = "t3.micro"
    subnet_key    = "public-1a"
    user_data     = "frontend.sh"
  }
  "backend" = {
    instance_type = "t3.micro"
    subnet_key    = "private-app-1a"   # Or private, depending on your design
    user_data     = "backend.sh"
  }
  "db" = {
    instance_type = "t3.micro"
    subnet_key    = "private-db-1a"
    user_data     = "db.sh"
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