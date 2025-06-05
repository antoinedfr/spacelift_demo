terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "ASIARGN4GVMC5NMMUAIY"
  secret_key = "d8s+secr3t+exemple+cle=oZ4zwtv08vUL5I/oCxMyQlypwG+9Gok0lZRW4a9X"
  token = "IQoJb3JpZ2luX2VjEGwaCXVzLXdlc3QtMiJIMEYCIQDKX1nw1rawKmkgQ6hlkKDbYu9RmXjsH7u6cM+CaWwyUAIhAKalCXkUh34n7yhoGOB0XchgixJgsMklu4wOgnJLzmlwKqMCCEUQABoMMDgyNTM1OTUxMTA5IgywhNhDZ8V742CPZKgqgAIX6k+MCuYZm1cmmPXCLRxLxUjqEo9JKY6IDrg98jsNscQqdh9c01rezpKde+L7h/Yrsab6IPYY9XtxDVe8iAGgZP/4A7zYH6F8ZyMzO6kDa5agwfqmnXooNg1+Zwg6aye1ZAKuBj41PRS38IRSPSB9nWymIzxKG+8IH0hLzr7eMUIOyQmgAbnpaxjzUaX6V7FtrAGphS1G7BoIS0Sxj6kJ2TxWmLsfHIHhmlS9InHUCUO3FeHlgBvBBwlll0+RBks0AZQ2r9ZucdiuCpSISTmLdsZJz0hJAmG3s7OFDnTQWaHbHY0nMMe6m6OD4p7yMi15ihX8GbFgolfH+w93jn42MJGRhsIGOpwBydt+r2x6xVb4Beq4d5RUwVcrSEr/jRO11azDOrEKVwwSFkqJw/+kEcPAnK5gXBVIPJBOHrcJJeuHqPhb6HiS+4YjKc2Ff3Jv1rEzzaNrBYZ7WKUuyLaOT19nZ17RA2yPsSCAzlnkuegohfa8yRNPVeaKhhRTyny1Au39EfKslkCkYWd0wcpYtfx1terkiz2PHIRWDNBZTCW8SMLh"
}

# Generate SSH key pair
resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key in SSM Parameter Store
resource "aws_ssm_parameter" "private_key" {
  name        = "/ssh/demo-keypair/private"
  description = "Private SSH key for EC2 demo"
  type        = "SecureString"
  value       = tls_private_key.demo_key.private_key_pem

  tags = {
    environment = "demo"
  }
}

# Create AWS key pair using the public key
resource "aws_key_pair" "demo_keypair" {
  key_name   = "demo-keypair"
  public_key = tls_private_key.demo_key.public_key_openssh
}

# Create VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "demo-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo-igw"
  }
}

# Route Table
resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "demo-rt"
  }
}

# Subnet
resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-subnet"
  }
}

# Route Table Association
resource "aws_route_table_association" "demo_rta" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_rt.id
}

# Security Group
resource "aws_security_group" "demo_sg" {
  name        = "demo-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-sg"
  }
}

# EC2 Instance
resource "aws_instance" "demo_instance" {
  ami                    = "ami-0779caf41f9ba54f0" // Replace with a valid AMI ID for your region
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.demo_subnet.id
  key_name               = aws_key_pair.demo_keypair.key_name
  vpc_security_group_ids = [aws_security_group.demo_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip python3-venv
  EOF

  tags = {
    Name = "demo-instance"
  }
}

# Outputs
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.demo_instance.public_ip
}
