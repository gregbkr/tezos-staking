provider "aws" {
  region  = "eu-west-3"
  profile = "finstack"
}

terraform {
  required_version = "~> 0.12.0"
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "gregbkr"
    workspaces {
      name = "tezos-node-testnet"
    }
  }
}

# VARS
variable "tag" {
  default = "tezos-node-testnet"
}
variable "az" {
  default = "eu-west-3a"
}
variable "env" {
  default = "dev"
}

# Fist get the default VPC and subnet IDs
data "aws_vpc" "default" {
  default = true
}
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# EC2
resource "aws_instance" "instance" {
  ami               = "ami-078db6d55a16afc82" # Ubuntu 20.04 (eu-west-3)
  instance_type     = "t2.medium"
  availability_zone = var.az
  key_name          = "finstack-eu-west-3"
  root_block_device {
    volume_type           = "gp2"
    volume_size           = "150"
    encrypted             = "true"
    delete_on_termination = "true"
  }
  vpc_security_group_ids = [aws_security_group.firewall.id]
  iam_instance_profile   = aws_iam_instance_profile.profile.name
  user_data              = file("cloud-config.yml")
  tags = {
    Name          = var.tag
    "Patch Group" = var.env
  }
    volume_tags = {
    Name          = var.tag
    Snapshot      = "daily"
  }
}

# # Elastic IP which will not change if instance get recreated
resource "aws_eip" "eip" {
  instance = aws_instance.instance.id
  vpc      = true
}

# Firewall
resource "aws_security_group" "firewall" {
  name        = var.tag
  description = "Security Group"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9732
    to_port     = 9732
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# OUTPUTS
output "instance_ip" {
  value = [aws_instance.instance.public_ip]
}
output "elastic_ip" {
  value = [aws_eip.eip.public_ip]
}
