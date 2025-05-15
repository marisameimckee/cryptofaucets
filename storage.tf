resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.app_name}-website"
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
    Name        = "${var.app_name}-website"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "app_assets" {
  bucket = "${var.app_name}-assets"
  acl    = "private"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  tags = {
    Name        = "${var.app_name}-assets"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "app_data" {
  name           = "${var.app_name}-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name        = "${var.app_name}-data-table"
    Environment = var.environment
  }
}