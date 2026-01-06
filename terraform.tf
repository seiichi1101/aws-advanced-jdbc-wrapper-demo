# ------------------------------------------------------------------------------
# Provider Configuration
# ------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = local.aws_region
}

# ------------------------------------------------------------------------------
# Variables (Input from terminal)
# ------------------------------------------------------------------------------
variable "ssh_public_key" {
  description = "SSH public key content (e.g., ssh-rsa AAAAB3...)"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Local Variables (All configuration in one place)
# ------------------------------------------------------------------------------
locals {
  # AWS Configuration
  aws_region = "eu-central-1"

  # Project Configuration
  project_name = "aws-jdbc-wrapper-demo"
  environment  = "dev"

  # Network Configuration
  vpc_cidr = "10.0.0.0/16"

  # Aurora Configuration
  aurora_database_name   = "test"
  aurora_master_username = "root"
  aurora_master_password = "password"

  # EC2 Configuration
  ec2_instance_type = "t3.micro"
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.project_name}-${local.environment}-vpc"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.project_name}-${local.environment}-igw"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Subnets for EC2 (Public)
# ------------------------------------------------------------------------------
resource "aws_subnet" "ec2_public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.project_name}-${local.environment}-ec2-public-${count.index + 1}"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Subnets for Aurora (Private)
# ------------------------------------------------------------------------------
resource "aws_subnet" "aurora_private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${local.project_name}-${local.environment}-aurora-private-${count.index + 1}"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Route Table for Public Subnets
# ------------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.project_name}-${local.environment}-public-rt"
    Environment = local.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.ec2_public)
  subnet_id      = aws_subnet.ec2_public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "aurora" {
  name       = "${local.project_name}-${local.environment}-aurora-subnet-group"
  subnet_ids = aws_subnet.aurora_private[*].id

  tags = {
    Name        = "${local.project_name}-${local.environment}-aurora-subnet-group"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Security Group for EC2
# ------------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${local.project_name}-${local.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from anywhere (adjust as needed)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${local.project_name}-${local.environment}-ec2-sg"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Key Pair for EC2
# ------------------------------------------------------------------------------
resource "aws_key_pair" "ec2" {
  key_name   = "${local.project_name}-${local.environment}-keypair"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${local.project_name}-${local.environment}-keypair"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Amazon Linux2 latest image
# ------------------------------------------------------------------------------
data "aws_ssm_parameter" "amzn2_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-ebs"
}

# ------------------------------------------------------------------------------
# EC2 Instance
# ------------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                    = nonsensitive(data.aws_ssm_parameter.amzn2_x86_64.value)
  instance_type          = local.ec2_instance_type
  subnet_id              = aws_subnet.ec2_public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.ec2.key_name

  # User data to install Java and MySQL client
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java-17-amazon-corretto mysql
              EOF

  tags = {
    Name        = "${local.project_name}-${local.environment}-app-server"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Security Group for Aurora
# ------------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name        = "${local.project_name}-${local.environment}-aurora-sg"
  description = "Security group for Aurora cluster"
  vpc_id      = aws_vpc.main.id

  # Allow MySQL access from EC2 security group
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
    description     = "MySQL access from EC2"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${local.project_name}-${local.environment}-aurora-sg"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Aurora Cluster Parameter Group
# ------------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "aurora" {
  name   = "${local.project_name}-${local.environment}-aurora-cluster-pg"
  family = "aurora-mysql8.0"
}

# ------------------------------------------------------------------------------
# Aurora DB Parameter Group
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "aurora" {
  name   = "${local.project_name}-${local.environment}-aurora-instance-pg"
  family = "aurora-mysql8.0"

  tags = {
    Name        = "${local.project_name}-${local.environment}-aurora-instance-pg"
    Environment = local.environment
  }
}

# ------------------------------------------------------------------------------
# Aurora Cluster
# ------------------------------------------------------------------------------
resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = "${local.project_name}-${local.environment}"
  engine                          = "aurora-mysql"
  engine_version                  = "8.0.mysql_aurora.3.04.3"
  database_name                   = local.aurora_database_name
  master_username                 = local.aurora_master_username
  master_password                 = local.aurora_master_password
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  # Storage encryption
  storage_encrypted = true

  # Apply changes immediately
  apply_immediately = true

  # Deletion protection
  deletion_protection = false

  lifecycle {
    ignore_changes = [master_password]
  }
}

# ------------------------------------------------------------------------------
# Aurora Cluster Instances (Multi-AZ)
# ------------------------------------------------------------------------------
# Writer Instance
resource "aws_rds_cluster_instance" "aurora_writer" {
  identifier                   = "${local.project_name}-${local.environment}-instance-1"
  cluster_identifier           = aws_rds_cluster.aurora.id
  instance_class               = "db.t3.medium"
  engine                       = aws_rds_cluster.aurora.engine
  db_parameter_group_name      = aws_db_parameter_group.aurora.name
  auto_minor_version_upgrade   = false
  performance_insights_enabled = false
  apply_immediately            = true
}

# Reader Instance
resource "aws_rds_cluster_instance" "aurora_reader" {
  identifier                   = "${local.project_name}-${local.environment}-instance-2"
  cluster_identifier           = aws_rds_cluster.aurora.id
  instance_class               = "db.t3.medium"
  engine                       = aws_rds_cluster.aurora.engine
  db_parameter_group_name      = aws_db_parameter_group.aurora.name
  auto_minor_version_upgrade   = false
  performance_insights_enabled = false
  apply_immediately            = true

  # Ensure reader is created after writer
  depends_on = [aws_rds_cluster_instance.aurora_writer]
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ec2_subnet_ids" {
  description = "EC2 subnet IDs"
  value       = aws_subnet.ec2_public[*].id
}

output "aurora_subnet_ids" {
  description = "Aurora subnet IDs"
  value       = aws_subnet.aurora_private[*].id
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "aurora_security_group_id" {
  description = "Aurora security group ID"
  value       = aws_security_group.aurora.id
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_cluster_id" {
  description = "Aurora cluster ID"
  value       = aws_rds_cluster.aurora.id
}

output "aurora_cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.aurora.port
}

output "aurora_database_name" {
  description = "Aurora database name"
  value       = aws_rds_cluster.aurora.database_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "EC2 instance public DNS"
  value       = aws_instance.app.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.app.public_ip}"
}

output "connection_info" {
  description = "Connection information"
  value = {
    ec2_public_ip          = aws_instance.app.public_ip
    aurora_writer_endpoint = aws_rds_cluster.aurora.endpoint
    aurora_reader_endpoint = aws_rds_cluster.aurora.reader_endpoint
    database_name          = aws_rds_cluster.aurora.database_name
    database_port          = aws_rds_cluster.aurora.port
  }
}
