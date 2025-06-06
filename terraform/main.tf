terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
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

# Subnets
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
  vpc_id                  = aws_vpc.three_tier_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "app-subnet"
  }
}

resource "aws_subnet" "db_subnet" {
  vpc_id                  = aws_vpc.three_tier_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "db-subnet"
  }
}

resource "aws_route_table_association" "web_rta" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.three_tier_rt.id
}

########################
# Security Groups
########################

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH to web tier"
  vpc_id      = aws_vpc.three_tier_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0]()_
