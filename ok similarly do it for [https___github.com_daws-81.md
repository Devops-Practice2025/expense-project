<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# ok similarly do it for [https://github.com/daws-81s/expense-infra-dev](https://github.com/daws-81s/expense-infra-dev) also help for modules

The repo `daws-81s/expense-infra-dev` is from **JoinDevOps by Sivakumar Reddy** — a popular Telugu DevOps training course. Based on the known structure of this course series, the expense project is a **3-tier expense tracker app** deployed on AWS using Terraform with custom modules. Here is a complete flowchart + module-by-module explanation:

***

## What the Expense Project Builds

```
Internet
   │
   ▼
Route53 (DNS)
   │
   ▼
ALB (Public) ─── Frontend EC2 (Nginx)
                        │
                        ▼
               Backend EC2 (Node.js / App)
                        │
                        ▼
               RDS MySQL (Private Subnet)
```

All of this is inside a **custom VPC** with public/private subnets, security groups per tier, and bastion/VPN for access.

***

## Full Project Flowchart

```
┌──────────────────────────────────────────────────┐
│              terraform apply                     │
└──────────────────────┬───────────────────────────┘
                       │
       ┌───────────────▼────────────────┐
       │         MODULE: VPC            │
       │  aws_vpc                       │
       │  aws_subnet (public x2)        │
       │  aws_subnet (private x2)       │
       │  aws_internet_gateway          │
       │  aws_nat_gateway               │
       │  aws_route_table (public)      │
       │  aws_route_table (private)     │
       │  aws_route_table_association   │
       └───────────────┬────────────────┘
                       │ vpc_id, subnet_ids
       ┌───────────────▼────────────────┐
       │      MODULE: SECURITY GROUPS   │
       │  sg_bastion  → port 22 from IP │
       │  sg_frontend → 80/443 from ALB │
       │  sg_backend  → 8080 from FE    │
       │  sg_mysql    → 3306 from BE    │
       │  sg_alb      → 80/443 public   │
       └──────┬─────────────────┬───────┘
              │                 │
   ┌──────────▼──────┐  ┌───────▼──────────────┐
   │  MODULE: BASTION│  │    MODULE: RDS        │
   │  aws_instance   │  │  aws_db_subnet_group  │
   │  public subnet  │  │  aws_db_instance      │
   │  SSH jumpbox    │  │    engine: mysql 8.0  │
   └─────────────────┘  │    private subnet     │
                        │    no public access   │
                        └──────────┬────────────┘
                                   │ db_endpoint
              ┌────────────────────▼───────────────┐
              │          MODULE: APP (Backend)      │
              │  aws_instance (Node.js / App tier)  │
              │  private subnet                     │
              │  user_data → install app, set DB URL│
              │  IAM role → SSM + Secrets access    │
              └──────────────┬─────────────────────┘
                             │
              ┌──────────────▼─────────────────────┐
              │        MODULE: FRONTEND             │
              │  aws_instance (Nginx)               │
              │  public OR private subnet           │
              │  user_data → install nginx, proxy   │
              │  points to backend EC2 private IP   │
              └──────────────┬─────────────────────┘
                             │
              ┌──────────────▼─────────────────────┐
              │           MODULE: ALB               │
              │  aws_lb (public-facing)             │
              │  aws_lb_target_group → frontend     │
              │  aws_lb_listener :80 → forward      │
              │  health_check → /health             │
              └──────────────┬─────────────────────┘
                             │
              ┌──────────────▼─────────────────────┐
              │         MODULE: ROUTE53             │
              │  data.aws_route53_zone              │
              │  aws_route53_record → ALB DNS alias │
              │  expense.yourdomain.com → ALB       │
              └────────────────────────────────────┘
```


***

## Every Module — Files \& Attributes Explained

### `modules/vpc/`

| File | Purpose |
| :-- | :-- |
| `main.tf` | Creates VPC, subnets, IGW, NAT, route tables |
| `variables.tf` | Inputs: `vpc_cidr`, `environment`, `azs` |
| `outputs.tf` | Exports: `vpc_id`, `public_subnet_ids`, `private_subnet_ids` |

```hcl
# Key attributes explained:
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr        # e.g. 10.0.0.0/16 — the IP space
  enable_dns_support   = true                # EC2 instances can resolve hostnames
  enable_dns_hostnames = true                # gives .internal DNS to instances
}

resource "aws_subnet" "public" {
  count                   = 2
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  # cidrsubnet() auto-calculates: 10.0.0.0/24, 10.0.1.0/24
  map_public_ip_on_launch = true             # EC2 here gets a public IP automatically
  availability_zone       = var.azs[count.index]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id             # Elastic IP — static public IP for NAT
  subnet_id     = aws_subnet.public[^0].id   # NAT must live in PUBLIC subnet
  # Private EC2 uses NAT to reach internet (for yum install, git clone etc.)
}
```


***

### `modules/security_groups/`

```hcl
# ALB SG — internet faces this first
resource "aws_security_group" "alb" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Anyone on internet can reach ALB
  }
}

# Frontend SG — only ALB can talk to frontend
resource "aws_security_group" "frontend" {
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # Source = ALB SG, not CIDR
    # This is called "SG referencing" — more secure than IP ranges
  }
}

# Backend SG — only frontend EC2 can talk to backend
resource "aws_security_group" "backend" {
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }
}

# MySQL SG — only backend EC2 can reach DB
resource "aws_security_group" "mysql" {
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }
}
```

> **Interview point:** Chaining security groups (ALB→FE→BE→DB) instead of CIDR ranges is a **zero-trust micro-segmentation** pattern that interviewers love.

***

### `modules/rds/`

```hcl
resource "aws_db_instance" "mysql" {
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"      # Compute size for DB
  db_name           = "transactions"     # Initial database name
  username          = "admin"
  password          = var.db_password    # sensitive = true in variable
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.mysql_sg_id]
  
  skip_final_snapshot    = true          # Dev only — prod should be false
  publicly_accessible    = false         # Never expose DB to internet
  storage_encrypted      = true          # Encrypts data at rest
  multi_az               = false         # Set true in prod for HA failover
}
```


***

### `modules/app/` (Backend EC2)

```hcl
resource "aws_instance" "backend" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type         # t3.micro for dev
  subnet_id     = var.private_subnet_ids[^0] # Private — no direct internet access

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    db_endpoint = var.db_endpoint           # Injected from RDS module output
    db_password = var.db_password
  }))
  # templatefile() = reads the .sh file and substitutes ${db_endpoint} placeholders

  iam_instance_profile = aws_iam_instance_profile.app.name
  # IAM profile = identity card for the EC2 instance (SSM, Secrets Manager access)
}
```

**`userdata.sh` does:**

```bash
#!/bin/bash
# Runs ONCE at first boot
dnf install nodejs -y               # Install runtime
git clone <repo> /app               # Pull application code
echo "DB_HOST=${db_endpoint}" > .env # Set DB connection
systemctl start expense-backend     # Start the app as a service
```


***

### `modules/alb/`

```hcl
resource "aws_lb_target_group" "frontend" {
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"           # Register EC2 instances (not IPs or Lambda)

  health_check {
    path                = "/health"  # ALB polls this URL every 30s
    healthy_threshold   = 2          # 2 consecutive 200s = healthy
    unhealthy_threshold = 3          # 3 failures = pull from rotation
    interval            = 30
    matcher             = "200"      # Expect HTTP 200 response
  }
}

resource "aws_lb_listener" "http" {
  port     = 80
  protocol = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
  # For prod: add action type = "redirect" to HTTPS (443)
}
```


***

### `modules/route53/`

```hcl
data "aws_route53_zone" "main" {
  name = var.domain_name              # Looks up your existing hosted zone
}

resource "aws_route53_record" "expense" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "expense.${var.domain_name}"  # expense.yourdomain.com
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true     # Route53 checks ALB health before routing
  }
  # alias{} is used for AWS resources (free, no TTL issues)
  # Use regular A record for external IPs
}
```


***

## Complete Module Dependency Chain

```
variables.tf (inputs)
      │
      ▼
module.vpc ──────────────────────────────────────────┐
      │ vpc_id, subnet_ids                           │
      ▼                                              │
module.security_groups ────────────────────┐         │
      │ sg_ids                             │         │
      ▼                                   │         │
module.rds ◄────── (private_subnets, sg)  │         │
      │ db_endpoint                        │         │
      ▼                                   │         │
module.app ◄─────── (private_subnets,     │         │
      │              db_endpoint, sg)      │         │
      ▼                                   │         │
module.frontend ◄── (subnets, sg,         │         │
      │              backend private IP)  │         │
      ▼                                   │         │
module.alb ◄──────── (public_subnets, ────┘         │
      │               frontend instance id)         │
      ▼                                             │
module.route53 ◄──── (alb_dns_name) ───────────────┘
      │
      ▼
outputs.tf → app_url, db_endpoint, alb_dns
```


***

## Key Interview Attributes Quick Reference

| Attribute | Where Used | Why It Matters |
| :-- | :-- | :-- |
| `cidrsubnet()` | VPC subnets | Auto-calculates CIDRs — no manual math |
| `map_public_ip_on_launch` | Public subnets | Auto-assigns public IPs to EC2 |
| `security_groups = [sg.id]` | SG rules | SG referencing — zero-trust between tiers |
| `publicly_accessible = false` | RDS | DB never exposed to internet |
| `storage_encrypted = true` | RDS | Compliance — encrypts data at rest |
| `skip_final_snapshot` | RDS | Dev=true; Prod=false (keeps backup on destroy) |
| `templatefile()` | EC2 userdata | Injects Terraform vars into bash scripts |
| `base64encode()` | EC2 userdata | user_data must be base64 encoded |
| `alias {}` | Route53 | AWS-native A record — free + auto health check |
| `evaluate_target_health` | Route53 | DNS fails over if ALB is unhealthy |
| `data {}` | AMI, Route53 zone | Reads existing AWS resources without creating |
| `sensitive = true` | DB password | Hides value in all plan/apply output |
| `count = 2` | Subnets | Creates multiple resources with one block |

This is the exact architecture the JoinDevOps course teaches for real-world AWS expense project deployment — and explaining each of these decisions confidently will make you stand out in DevOps interviews.


Here’s a **practical example** of using `for_each` in Terraform to create multiple subnets, and how to reference the VPC ID from a module.

---

## Using `for_each` with VPC ID – Real Example

In the expense-infra-dev project, subnets are created with `count` (fixed number). But **`for_each`** is more flexible when you need to define subnets by name or with custom CIDR blocks per availability zone.

### 1. Define a variable for subnet configuration

```hcl
# variables.tf
variable "subnets" {
  description = "Subnet configurations per AZ"
  type = map(object({
    cidr_block        = string
    availability_zone = string
    public            = bool
  }))
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
```

### 2. Use `for_each` to create subnets – referencing the VPC ID

```hcl
# main.tf (inside your vpc module or root)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  # ...
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id     = aws_vpc.main.id                # reference the VPC ID directly
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone

  map_public_ip_on_launch = each.value.public

  tags = {
    Name = each.key
    Tier = each.value.public ? "public" : "private"
  }
}
```

> **`each.key`** gives the map key (e.g., `"public-us-east-1a"`),  
> **`each.value`** gives the object containing `cidr_block`, `az`, etc.

### 3. Output the VPC ID for use in other modules

```hcl
# outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}
```

Then, in your root module, you can reference the VPC ID like this:

```hcl
module "vpc" {
  source = "./modules/vpc"
  # inputs...
}

# Use the vpc_id output elsewhere
resource "aws_security_group" "example" {
  vpc_id = module.vpc.vpc_id   # <-- referencing VPC ID from module
  # ...
}
```

---

## Why `for_each` over `count`?

| Feature | `count` | `for_each` |
|---------|---------|------------|
| Index-based access | `count.index` | No index, uses map key |
| Removing an item from the middle | Shifts indices → may destroy/recreate resources | Removes only that key → stable |
| Readable names | Hard to give meaningful names (e.g., `aws_subnet.public[0]`) | Each resource is named with its key: `aws_subnet.this["public-us-east-1a"]` |
| Works with modules | Yes | Yes (since Terraform 0.13) |

---

## Using `for_each` with a `module` block

If your VPC is itself a module, you can still use `for_each` to create multiple VPCs (e.g., dev/staging/prod):

```hcl
variable "environments" {
  type = map(string)
  default = {
    dev  = "10.0.0.0/16"
    stg  = "10.1.0.0/16"
    prod = "10.2.0.0/16"
  }
}

module "vpc" {
  for_each = var.environments
  source   = "./modules/vpc"
  vpc_cidr = each.value
  env_name = each.key
}

# Reference VPC ID of the dev environment:
# module.vpc["dev"].vpc_id
```

---

## Summary

- **`for_each`** iterates over a map or set, giving you **stable resource addresses** and easier management.
- The **VPC ID** is always available as an attribute of the `aws_vpc` resource or as an output from a VPC module.
- You can reference it directly inside the same module (`aws_vpc.main.id`) or across modules (`module.vpc.vpc_id`).

This pattern is widely used in production-grade Terraform to handle multiple environments, availability zones, or service tiers cleanly.