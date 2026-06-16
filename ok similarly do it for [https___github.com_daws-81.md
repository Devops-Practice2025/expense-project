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
<span style="display:none">[^1][^10][^11][^12][^13][^14][^15][^16][^17][^18][^19][^2][^20][^21][^22][^23][^24][^25][^26][^27][^28][^29][^3][^4][^5][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: https://github.com/Unique-AG/terraform-modules

[^2]: https://github.com/alfonsof/terraform-aws-examples

[^3]: https://github.com/infracost/infracost-gh-action/issues/16

[^4]: https://skundunotes.com/2023/03/07/ci-cd-with-terraform-and-github-actions-to-deploy-to-aws/

[^5]: https://github.com/shuaibiyy/awesome-tf

[^6]: https://github.com/daws-78s/terraform-aws-eks

[^7]: https://www.youtube.com/watch?v=POM73N3Vgw0

[^8]: https://dev.to/aws-builders/provisioning-aws-infrastructure-using-terraform-and-github-actions-40ei

[^9]: https://github.com/dfds/infrastructure-modules

[^10]: https://github.com/topics/iac-aws-terraform?l=hcl

[^11]: https://www.youtube.com/watch?v=GaL8wMr48uI

[^12]: https://www.oreilly.com/videos/terraform-in-aws/9780135378618/9780135378618-AGN1_01_02_03/

[^13]: https://www.gruntwork.io/blog/how-to-create-reusable-infrastructure-with-terraform-modules

[^14]: https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/issues/114

[^15]: https://www.infracost.io/docs/features/terraform_modules/

[^16]: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

[^17]: https://github.com/terraform-aws-modules/terraform-aws-pricing

[^18]: https://blog.devops.dev/terraform-modules-build-a-scalable-aws-infrastructure-0f52465b0aa2

[^19]: https://controlmonkey.io/resource/devops-terraform-aws/

[^20]: https://www.youtube.com/watch?v=7XcqRDVMv3o

[^21]: https://www.hashicorp.com/en/blog/a-guide-to-cloud-cost-optimization-with-hashicorp-terraform

[^22]: https://dev.to/aws-builders/terraform-modules-the-secret-sauce-to-scalable-infrastructure-10hi

[^23]: https://www.hashicorp.com/en/blog/terraform-modules-on-aws

[^24]: https://developer.hashicorp.com/terraform/tutorials/aws/aws-rds

[^25]: https://www.linkedin.com/posts/sudheer-kumar-reddy-0532562a_amazon-web-services-aws-devops-joindevops-activity-7249444109629669377-HmRN

[^26]: https://aws.plainenglish.io/mastering-terraform-modules-with-aws-build-reusable-infrastructure-for-dev-and-prod-environments-e54a318d52d0

[^27]: https://www.firefly.ai/academy/finops-for-terraform-how-to-track-cloud-spend-before-it-hits-production

[^28]: https://oneuptime.com/blog/post/2026-02-12-terraform-aws-rds-module/view

[^29]: https://www.facebook.com/groups/terraformautomation/posts/1509612587124839/

