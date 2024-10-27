#  Define the provider
provider "aws" {
  region = "us-east-1"
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Data block to retrieve the default VPC id
data "aws_vpc" "default" {
  default = true
}

# Define tags locally
locals {
  default_tags = merge(module.globalvars.default_tags, { "env" = var.env })
  prefix       = module.globalvars.prefix
  name_prefix  = "${local.prefix}-${var.env}"
}

# Retrieve global variables from the Terraform module
module "globalvars" {
  source = "../../modules/globalvars"
}

# Data source to retrieve existing subnets
data "aws_subnet" "existing_subnets" {
  count = 6 # Number of existing subnets you have
  id = [
    "subnet-00a28d5714717e929",
    "subnet-08882d0682246aa05",
    "subnet-0ab71df8e955b0f10",
    "subnet-0ba141b036541a1ac",
    "subnet-0a6cc085f04eef096",
    "subnet-0c28530ade5687e94",
  ][count.index]
}


# Reference subnet provisioned by 01-Networking 
resource "aws_instance" "my_amazon" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.my_key.key_name
  vpc_security_group_ids      = [aws_security_group.my_sg.id]
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.existing_subnets[0].id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-Amazon-Linux"
    }
  )
}


# Adding SSH key to Amazon EC2
resource "aws_key_pair" "my_key" {
  key_name   = local.name_prefix
  public_key = file("${local.name_prefix}.pub")
}

# Security Group
resource "aws_security_group" "my_sg" {
  name        = "allow_ssh_http_https_sql"
  description = "Allow SSH, HTTP, HTTPS, and SQL inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS from everywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SQL (MySQL) from specific IP"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-sg"
    }
  )
}


# Elastic IP
resource "aws_eip" "static_eip" {
  instance = aws_instance.my_amazon.id
  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-eip"
    }
  )
}

# Create AWS ECR Repository
resource "aws_ecr_repository" "my_ecr_repo" {
  name                 = "${local.name_prefix}-ecr" # Ensure this is a valid name
  image_tag_mutability = "MUTABLE"                  # Can be MUTABLE or IMMUTABLE
  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-ecr"
    }
  )
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow traffic to the Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id # Ensure you have a VPC defined

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP traffic from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-alb-sg" # Tag for identification
    }
  )
}

# Create the Application Load Balancer
resource "aws_lb" "my_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]         # Use the ALB security group
  subnets            = data.aws_subnet.existing_subnets[*].id # Associate with the existing subnets

  enable_deletion_protection = false

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-alb" # Tag for identification
    }
  )
}

# Create a Target Group for your ALB
resource "aws_lb_target_group" "my_target_group" {
  name     = "${local.name_prefix}-tg"
  port     = 80 # Change this if your application runs on a different port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id # Ensure you have a VPC defined

  health_check {
    path                = "/health" # Change this to your application's health check path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-tg" # Tag for identification
    }
  )
}

# Create a Listener for the ALB (HTTP)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}
