variable "vpc_cidr" {
  
}
variable "env" {
  
}

variable "subnets" {
  default = {
    "public-us-east-1a" = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1a"
      public            = true
    }
    "public-us-east-1b" = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "us-east-1b"
      public            = true
    }
    "private-us-east-1a" = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "us-east-1a"
      public            = false
    }
    "private-us-east-1b" = {
      cidr_block        = "10.0.11.0/24"
      availability_zone = "us-east-1b"
      public            = false
    }
  }
}
  