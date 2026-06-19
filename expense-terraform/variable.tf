# variables.tf
variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "vpc_config" {
  type = object({
    cidr_block = string
  })
}

# Map of objects for subnets
variable "subnets" {
  description = "Subnet configurations"
  type = map(object({
    cidr_block        = string
    availability_zone = string
    is_public         = bool
  }))
}

# Map of objects for EC2 instances
variable "instances" {
  description = "EC2 instance configurations"
  type = map(object({
    instance_type = string
    subnet_key    = string
    user_data     = string
  }))
}

# Map for SG rules
variable "sg_rules" {
  description = "Security group rules"
  type = map(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    target_sg   = string
  }))
  default = {} # Optional
}
