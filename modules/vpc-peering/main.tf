# VPC Peering Module
# Creates VPC peering connections between accounts for cross-account communication

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account" {
  description = "Account type (app, ml, shared)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "peer_vpc_cidrs" {
  description = "List of peer VPC CIDR blocks"
  type        = list(string)
  default     = []
}

variable "peer_account_ids" {
  description = "List of peer account IDs"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.env}-${var.account}-vpc"
    Environment = var.env
    Account     = var.account
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.env}-${var.account}-igw"
    Environment = var.env
    Account     = var.account
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count = length(var.region) > 0 ? 2 : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = "${var.region}-${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.env}-${var.account}-public-subnet-${count.index == 0 ? "a" : "b"}"
    Environment = var.env
    Account     = var.account
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count = length(var.region) > 0 ? 2 : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = "${var.region}-${count.index == 0 ? "a" : "b"}"

  tags = {
    Name        = "${var.env}-${var.account}-private-subnet-${count.index == 0 ? "a" : "b"}"
    Environment = var.env
    Account     = var.account
  }
}

# Create Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.env}-${var.account}-public-rt"
    Environment = var.env
    Account     = var.account
  }
}

# Associate Public Subnets with Route Table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.env}-${var.account}-private-rt"
    Environment = var.env
    Account     = var.account
  }
}

# Associate Private Subnets with Route Table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.env}-${var.account}-nat-eip"
    Environment = var.env
    Account     = var.account
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.env}-${var.account}-nat"
    Environment = var.env
    Account     = var.account
  }

  depends_on = [aws_internet_gateway.main]
}

# Add route to NAT Gateway in private route table
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Create VPC Peering Connections
resource "aws_vpc_peering_connection" "peer" {
  count = length(var.peer_vpc_cidrs)

  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = var.peer_vpc_cidrs[count.index]
  peer_owner_id = var.peer_account_ids[count.index]
  peer_region   = var.region
  auto_accept   = false

  tags = {
    Name        = "${var.env}-${var.account}-to-peer-${count.index}"
    Environment = var.env
    Account     = var.account
  }
}

# Accept VPC Peering Connections
resource "aws_vpc_peering_connection_accepter" "peer" {
  count = length(aws_vpc_peering_connection.peer)

  vpc_peering_connection_id = aws_vpc_peering_connection.peer[count.index].id
  auto_accept               = true

  tags = {
    Name        = "${var.env}-${var.account}-peer-accepter-${count.index}"
    Environment = var.env
    Account     = var.account
  }
}

# Add routes for peered VPCs
resource "aws_route" "peer" {
  count = length(var.peer_vpc_cidrs)

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.peer_vpc_cidrs[count.index]
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer[count.index].id
}

# Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}