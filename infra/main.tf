terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Amazon Linux 2023 ARM64 (aarch64)
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

# Security Group: allow only YOUR IP to reach app/Prometheus/Grafana
resource "aws_security_group" "demo" {
  name        = "demo-observability-sg"
  description = "Allow Grafana/Prometheus/API from my IP only"

  ingress {
    description = "API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # No SSH ingress on purpose

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM: EC2 assume role
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "demo-observability-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

# Enable SSM Session Manager login (no SSH keys needed)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege permission to read ONLY your secret
resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = var.secret_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "demo-observability-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 instance
resource "aws_instance" "demo" {
  ami                    = data.aws_ami.al2023_arm.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.demo.id]
  iam_instance_profile   = aws_iam_instance_profile.profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker git
    systemctl enable --now docker

    # Docker Compose v2 plugin (ARM64)
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    cd /opt
    git clone ${var.repo_url} apprepo
    cd apprepo

    # Provide the secret name to the compose stack
    echo "SECRET_ID=${var.secret_name}" > .env

    docker compose up -d --build
  EOF

  tags = {
    Name = "demo-observability"
  }
}

output "public_ip" {
  value = aws_instance.demo.public_ip
}

output "instance_id" {
  value = aws_instance.demo.id
}