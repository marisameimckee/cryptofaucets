provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # Free tier eligible
}

variable "app_name" {
  description = "Name of the blockchain application"
  type        = string
  default     = "blockchain-tx"
}

resource "aws_vpc" "faucet_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

resource "aws_subnet" "faucet_subnet" {
  vpc_id                  = aws_vpc.faucet_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  
  tags = {
    Name = "${var.app_name}-subnet"
  }
}

resource "aws_internet_gateway" "faucet_igw" {
  vpc_id = aws_vpc.faucet_vpc.id
  
  tags = {
    Name = "${var.app_name}-igw"
  }
}

resource "aws_route_table" "faucet_rt" {
  vpc_id = aws_vpc.faucet_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.faucet_igw.id
  }
  
  tags = {
    Name = "${var.app_name}-rt"
  }
}

resource "aws_route_table_association" "faucet_rta" {
  subnet_id      = aws_subnet.faucet_subnet.id
  route_table_id = aws_route_table.faucet_rt.id
}

resource "aws_security_group" "faucet_sg" {
  name        = "${var.app_name}-sg"
  description = "Security group for crypto faucet application"
  vpc_id      = aws_vpc.faucet_vpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "${var.app_name}-sg"
  }
}

resource "aws_instance" "faucet_server" {
  ami                    = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (adjust for your region)
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.faucet_subnet.id
  vpc_security_group_ids = [aws_security_group.faucet_sg.id]
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              systemctl enable docker
              # Additional setup commands for the faucet application would go here
              EOF
  
  tags = {
    Name = "${var.app_name}-server"
  }
}

resource "aws_eip" "faucet_eip" {
  instance = aws_instance.faucet_server.id
  vpc      = true
  
  tags = {
    Name = "${var.app_name}-eip"
  }
}

output "faucet_server_public_ip" {
  value = aws_eip.faucet_eip.public_ip
}

variable "blockchain_network" {
  description = "Blockchain network to use (ethereum, bitcoin, etc.)"
  type        = string
  default     = "ethereum"
}

variable "rpc_endpoint" {
  description = "RPC endpoint URL for the blockchain node"
  type        = string
  default     = "https://mainnet.infura.io/v3/your-api-key"
}

variable "explorer_base_url" {
  description = "Base URL for the blockchain explorer"
  type        = map(string)
  default = {
    ethereum = "https://etherscan.io"
    bitcoin  = "https://blockstream.info"
    polygon  = "https://polygonscan.com"
    bsc      = "https://bscscan.com"
  }
}

variable "confirmation_blocks" {
  description = "Number of blocks required for transaction confirmation"
  type        = map(number)
  default = {
    ethereum = 12
    bitcoin  = 6
    polygon  = 64
    bsc      = 15
  }
}

resource "aws_dynamodb_table" "blockchain_transactions" {
  name           = "${var.app_name}-transactions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "tx_hash"
  range_key      = "created_at"

  attribute {
    name = "tx_hash"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  attribute {
    name = "wallet_address"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name               = "WalletAddressIndex"
    hash_key           = "wallet_address"
    range_key          = "created_at"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    range_key          = "created_at"
    projection_type    = "ALL"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name        = "${var.app_name}-transactions-table"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}

resource "aws_s3_bucket" "blockchain_explorer" {
  bucket = "${var.app_name}-explorer-${var.blockchain_network}"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  tags = {
    Name        = "${var.app_name}-explorer-${var.blockchain_network}"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}

resource "aws_s3_bucket_policy" "blockchain_explorer_policy" {
  bucket = aws_s3_bucket.blockchain_explorer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.blockchain_explorer.arn}/*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "blockchain_explorer_distribution" {
  origin {
    domain_name = aws_s3_bucket.blockchain_explorer.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.blockchain_explorer.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.blockchain_explorer.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.app_name}-explorer-distribution"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}