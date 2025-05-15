resource "aws_iam_role" "app_role" {
  name = "${var.app_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "app_policy" {
  name = "${var.app_name}-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.app_data.arn
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.website_bucket.arn,
          "${aws_s3_bucket.website_bucket.arn}/*",
          aws_s3_bucket.app_assets.arn,
          "${aws_s3_bucket.app_assets.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.app_name}-profile"
  role = aws_iam_role.app_role.name
}

resource "aws_instance" "app_server" {
  ami                    = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (adjust for your region)
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.app_profile.name
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              systemctl enable docker
              
              # Install application dependencies
              yum install -y git
              
              # Clone application repository
              mkdir -p /app
              
              # Set up application
              docker run -d -p 80:80 --name web-app nginx:latest
              
              # Additional setup commands would go here
              EOF
  
  tags = {
    Name        = "${var.app_name}-server"
    Environment = var.environment
  }
}

resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  vpc      = true
  
  tags = {
    Name        = "${var.app_name}-eip"
    Environment = var.environment
  }
}