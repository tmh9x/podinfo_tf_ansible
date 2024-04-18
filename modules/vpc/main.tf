variable "cidr" {}
variable "region" {}
variable "az" {}

resource "aws_vpc" "main" {
  cidr_block = var.cidr
  enable_dns_hostnames = true

  tags = {
    Name = "AWS VPC"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id  
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = aws_vpc.main.cidr_block
  availability_zone = var.az
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route_table.id
}

