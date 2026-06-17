# expense-project
Expense project
Perfect! Using **`tfvars` + maps + modules** is the **industry-standard** way to write scalable Terraform. 

In the **JoinDevOps expense project**, you don't hardcode values in `main.tf`. Instead, you define everything as **maps** in `terraform.tfvars`, pass those maps into your root module, and use **`for_each`** inside your custom modules to dynamically create resources.

Here is a complete, copy-paste-ready example that mirrors the **expense-infra-dev** architecture.

---

## 1. File Structure
```
expense-infra-dev/
├── terraform.tfvars         # All your maps live here
├── variables.tf             # Defines the complex map types
├── main.tf                  # Calls modules, passing the maps
├── outputs.tf               # Prints the results
└── modules/
    ├── networking/          # Creates VPC, Subnets, IGW, NAT
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── compute/             # Creates EC2 (Bastion/FE/BE)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 2. `terraform.tfvars` (The Source of Truth)

Here we use **nested maps** to define subnets, EC2 instances, and security group rules.

```hcl
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
    instance_type = "t3.nano"
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
```

---

## 3. Root `variables.tf` (Define the Complex Types)

Terraform needs to know the structure of your maps to validate them.

```hcl
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
```

---

## 4. `modules/networking/` (Receives the Map & Creates Resources)

### `modules/networking/variables.tf`
```hcl
variable "environment" {}
variable "vpc_config" {}
variable "subnets" {} # Accepts the whole map from tfvars
```

### `modules/networking/main.tf`
```hcl
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
```

### `modules/networking/outputs.tf` (Pass filtered maps back)
```hcl
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
```

---

## 5. `modules/compute/` (Receives the Instance Map & Subnet Map)

### `modules/compute/variables.tf`
```hcl
variable "environment" {}
variable "instances" {}       # Map from tfvars
variable "subnet_ids" {}      # Map received from networking module
```

### `modules/compute/main.tf`
```hcl
# Data source for AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create EC2 instances dynamically from the map
resource "aws_instance" "this" {
  for_each = var.instances

  ami                    = data.aws_ami.amazon_linux.id
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
```

---

## 6. Root `main.tf` (Glue Everything Together)

```hcl
# main.tf

# 1. Call the Networking module, passing the maps from tfvars
module "networking" {
  source = "./modules/networking"

  environment = var.environment
  vpc_config  = var.vpc_config
  subnets     = var.subnets
}

# 2. Call the Compute module, passing the instance map 
#    AND the subnet_ids output from the networking module
module "compute" {
  source = "./modules/compute"

  environment = var.environment
  instances   = var.instances
  subnet_ids  = module.networking.subnet_ids # Passing the MAP of subnet IDs
  vpc_id      = module.networking.vpc_id
}
```

---

## 7. Root `outputs.tf` (See the magic)

```hcl
output "vpc_id" {
  value = module.networking.vpc_id
}

# Shows you the map of all subnets -> IDs
output "subnet_id_map" {
  value = module.networking.subnet_ids
}

# Shows you the map of instances -> Private IPs
output "instance_ip_map" {
  value = { for k, v in module.compute.this : k => v.private_ip } # You need to export this in compute outputs
}
```

---

## The Flow of Data (Visual)

```
terraform.tfvars
│
│  subnets = { "public-1a" = {...}, "private-1a" = {...} }
│
▼
variables.tf  (Validates the map structure)
│
▼
main.tf (Passes the map to module)
│
module "networking" {
  subnets = var.subnets   <── The WHOLE map goes in
}
│
▼
modules/networking/main.tf
│
resource "aws_subnet" "this" {
  for_each = var.subnets   <── Iterates over each key in the map
  cidr_block = each.value.cidr_block
}
│
▼
modules/networking/outputs.tf
│
output "subnet_ids" {
  value = { for k, v in aws_subnet.this : k => v.id }  <── Returns a NEW map
}
│
▼
main.tf (Second module)
│
module "compute" {
  subnet_ids = module.networking.subnet_ids  <── Receives the MAP of IDs
}
│
▼
modules/compute/main.tf
│
resource "aws_instance" "this" {
  for_each = var.instances
  subnet_id = var.subnet_ids[each.value.subnet_key]  <── Dynamically picks the right subnet ID
}
```

---

## 🔥 Key Takeaways for Your Expense Project

1. **No hardcoded values**: Everything from CIDR blocks to instance types lives in `terraform.tfvars`.
2. **Modules are pure logic**: They don't know if they are "dev" or "prod"—they just render the maps they receive.
3. **Map chaining**: The output of the `networking` module (a map of subnet IDs) becomes the input to the `compute` module. This is exactly how you link the Frontend EC2 (public subnet) and Backend EC2 (private subnet) in the expense app.
4. **Adding a new AZ**: Just add a new block in the `subnets` map in `tfvars`. Run `terraform plan`—you'll see only ONE new subnet get created (no shuffling of indexes like with `count`).

**Pro Interview Tip**: "I use `for_each` with maps in `tfvars` instead of `count` because it provides **stable resource addresses**. If I remove `private-1b` from the map, Terraform only destroys that one resource, whereas `count` would destroy and recreate `private-1b` and `private-2b` due to index shifts."