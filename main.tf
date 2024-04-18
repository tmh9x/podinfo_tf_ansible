provider "aws" {
  alias = "eu"
  region = "eu-central-1"
}

module "vpc" {
  source = "./modules/vpc"
  cidr = "10.0.0.0/16"
  region = "eu-central-1"
  az = "eu-central-1a"
}

module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id
}

resource "aws_key_pair" "aws_key" {
  key_name   = "ansible-ssh-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

module "ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"
  count  = var.instance_count
  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = aws_key_pair.aws_key.key_name
  subnet_id       = module.vpc.subnet_id
  vpc_security_group_ids = [module.security_groups.allow_ssh, module.security_groups.allow_http]
  associate_public_ip_address = true
}

output "instance_ids" {
  value = [for instance in module.ec2 : instance.id]
}

output "public_ips" {
  value = [for instance in module.ec2 : instance.public_ip]
}