# Provision EC2 mit Terraform und Configure mit Ansible
### Was ist Terraform?
Mit Terraform können wir unsere gesamte Infrastruktur in Code beschreiben, sogar über mehrere Service-Provider hinweg (Beispiel: Server liegen auf AWS, DNS ist von CloudFlare und Datenbank liegt in Azure). Terraform erstellt uns all diese Ressourcen parallel für all diese Provider. Insgesamt sollten wir uns merken, dass Terraform eins der besten Tools ist, um die Infrastruktur vorzubereiten und aufzustellen.
### Was ist Ansible?
Ansible ist ein IT Automatisierungs-Tool. Wir nutzen es beispielsweise, um Virtuelle Maschinen, die wir mit Terraform erstellt haben, zu konfigurieren. Ansible kann ebenso Software deployen und komplexere IT-Tasks, wie Continous Deployment oder Updates übernehmen, ohne dass dabei Ausfallzeit entsteht.

## Tutorial
#### Provision einer EC2 Instanz mit Terraform
Wir werden für das Provisioning der EC2-Instanz wieder Module verwenden. Dazu erstellen wir uns zunächst das VPC-Modul in dem Ordner `modules/voc/main.tf`:
```
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

```