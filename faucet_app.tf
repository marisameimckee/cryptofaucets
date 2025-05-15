resource "aws_dynamodb_table" "faucet_requests" {
  name           = "${var.app_name}-requests"
  billing_mode   = "PAY_PER_REQUEST" # Start with on-demand pricing for cost efficiency
  hash_key       = "ip_address"
  range_key      = "request_time"

  attribute {
    name = "ip_address"
    type = "S"
  }

  attribute {
    name = "request_time"
    type = "S"
  }

  attribute {
    name = "wallet_address"
    type = "S"
  }

  global_secondary_index {
    name               = "WalletAddressIndex"
    hash_key           = "wallet_address"
    range_key          = "request_time"
    projection_type    = "ALL"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name = "${var.app_name}-requests-table"
  }
}

resource "aws_s3_bucket" "faucet_static" {
  bucket = "${var.app_name}-static-assets"
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
    Name = "${var.app_name}-static-assets"
  }
}

resource "aws_cloudfront_distribution" "faucet_distribution" {
  origin {
    domain_name = aws_s3_bucket.faucet_static.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.faucet_static.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.faucet_static.bucket}"

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
    Name = "${var.app_name}-distribution"
  }
}

resource "aws_iam_role" "faucet_role" {
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
    Name = "${var.app_name}-role"
  }
}

resource "aws_iam_role_policy" "faucet_policy" {
  name = "${var.app_name}-policy"
  role = aws_iam_role.faucet_role.id

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
        Resource = aws_dynamodb_table.faucet_requests.arn
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.faucet_static.arn,
          "${aws_s3_bucket.faucet_static.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "faucet_profile" {
  name = "${var.app_name}-profile"
  role = aws_iam_role.faucet_role.name
}

resource "aws_instance" "faucet_server" {
  # This is a reference to the existing resource in main.tf
  # The actual resource is defined there, this just adds the IAM profile
  iam_instance_profile = aws_iam_instance_profile.faucet_profile.name
}