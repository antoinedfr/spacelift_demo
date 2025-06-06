
terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

########################
# SSH Keys Per Tier
########################

resource "tls_private_key" "web_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ssm_parameter" "web_private_key" {
  name        = "/ssh/web-keypair/private"
  description = "Private SSH key for Web tier"
  type        = "SecureString"
  value       = tls_private_key.web_key.private_key_pem
  tags = {
    environment = "three-tier"
  }
}

resource "aws_key_pair" "web_keypair" {
  key_name   = "web-keypair"
  public_key = tls_private_key.web_key.public_key_openssh
}

resource "tls_private_key" "app_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ssm_parameter" "app_private_key" {
  name        = "/ssh/app-keypair/private"
  description = "Private SSH key for App tier"
  type        = "SecureString"
  value       = tls_private_key.app_key.private_key_pem
  tags = {
    environment = "three-tier"
  }
}

resource "aws_key_pair" "app_keypair" {
  key_name   = "app-keypair"
  public_key = tls_private_key.app_key.public_key_openssh
}

resource "tls_private_key" "db_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ssm_parameter" "db_private_key" {
  name        = "/ssh/db-keypair/private"
  description = "Private SSH key for DB tier"
  type        = "SecureString"
  value       = tls_private_key.db_key.private_key_pem
  tags = {
    environment = "three-tier"
  }
}

resource "aws_key_pair" "db_keypair" {
  key_name   = "db-keypair"
  public_key = tls_private_key.db_key.public_key_openssh
}

########################
# Networking
########################

resource "aws_vpc" "three_tier_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "three-tier-vpc"
  }
}

resource "aws_internet_gateway" "three_tier_igw" {
  vpc_id = aws_vpc.three_tier_vpc.id

  tags = {
    Name = "three-tier-igw"
  }
}

resource "aws_route_table" "three_tier_rt" {
  vpc_id = aws_vpc.three_tier_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.three_tier_igw.id
  }

  tags = {
    Name = "three-tier-rt"
  }
}

resource "aws_subnet" "web_subnet" {
  vpc_id                  = aws_vpc.three_tier_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "web-subnet"
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "app-subnet"
  }
}

resource "aws_subnet" "db_subnet" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "db-subnet"
  }
}

resource "aws_route_table_association" "web_rta" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.three_tier_rt.id
}

resource "aws_route_table_association" "app_rta" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.three_tier_rt.id
}

resource "aws_route_table_association" "db_rta" {
  subnet_id      = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.three_tier_rt.id
}

########################
# Security Groups
########################

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP from internet and SSH from Azure"
  vpc_id      = aws_vpc.three_tier_vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from Azure over VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Allow App tier access from Web tier and SSH from Azure"
  vpc_id      = aws_vpc.three_tier_vpc.id

  ingress {
    description = "App traffic from Web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description = "SSH from Azure over VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL from App tier and SSH from Azure"
  vpc_id      = aws_vpc.three_tier_vpc.id

  ingress {
    description = "MySQL from App tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    description = "SSH from Azure over VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# EC2 Instances
########################

resource "aws_instance" "web_instance" {
  ami                    = "ami-0779caf41f9ba54f0"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web_subnet.id
  key_name               = aws_key_pair.web_keypair.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "web-instance"
  }
}

resource "aws_instance" "app_instance" {
  ami                    = "ami-0779caf41f9ba54f0"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  key_name               = aws_key_pair.app_keypair.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3-flask
    echo "from flask import Flask; app = Flask(__name__); @app.route('/')
def hello(): return 'Hello from App tier'; app.run(host='0.0.0.0', port=8080)" > /home/ubuntu/app.py
    nohup python3 /home/ubuntu/app.py &
  EOF

  tags = {
    Name = "app-instance"
  }
}

resource "aws_instance" "db_instance" {
  ami                    = "ami-0779caf41f9ba54f0"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.db_subnet.id
  key_name               = aws_key_pair.db_keypair.key_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y mysql-server
    systemctl start mysql
  EOF

  tags = {
    Name = "db-instance"
  }
}

########################
# VPN IPSec to Azure
########################

resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65000
  ip_address = "4.246.147.155"
  type       = "ipsec.1"

  tags = {
    Name = "azure-cgw"
  }
}

resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.three_tier_vpc.id

  tags = {
    Name = "aws-vpn-gw"
  }
}

resource "aws_vpn_connection" "azure_vpn" {
  customer_gateway_id     = aws_customer_gateway.azure.id
  vpn_gateway_id          = aws_vpn_gateway.vpn_gw.id
  type                    = "ipsec.1"
  static_routes_only      = true

  tunnel1_preshared_key   = "Projet_AWAZ10"
  tunnel1_inside_cidr     = "169.254.21.0/30"

  tags = {
    Name = "vpn-aws-to-azure"
  }
}

resource "aws_vpn_connection_route" "route_to_azure" {
  vpn_connection_id      = aws_vpn_connection.azure_vpn.id
  destination_cidr_block = "192.168.2.0/24"
}

resource "aws_route" "route_to_azure_vpn" {
  route_table_id         = aws_route_table.three_tier_rt.id
  destination_cidr_block = "192.168.2.0/24"
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}
