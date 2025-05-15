resource "aws_iam_role" "blockchain_lambda_role" {
  name = "${var.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-lambda-role"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}

resource "aws_iam_role_policy" "blockchain_lambda_policy" {
  name = "${var.app_name}-lambda-policy"
  role = aws_iam_role.blockchain_lambda_role.id

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
        Resource = aws_dynamodb_table.blockchain_transactions.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "submit_transaction" {
  function_name    = "${var.app_name}-submit-transaction"
  role             = aws_iam_role.blockchain_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  filename         = "lambda_functions/submit_transaction.zip"
  source_code_hash = filebase64sha256("lambda_functions/submit_transaction.zip")
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      BLOCKCHAIN_NETWORK = var.blockchain_network
      RPC_ENDPOINT       = var.rpc_endpoint
      EXPLORER_BASE_URL  = var.explorer_base_url[var.blockchain_network]
      DYNAMODB_TABLE     = aws_dynamodb_table.blockchain_transactions.name
    }
  }

  tags = {
    Name        = "${var.app_name}-submit-transaction"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}

resource "aws_lambda_function" "verify_transaction" {
  function_name    = "${var.app_name}-verify-transaction"
  role             = aws_iam_role.blockchain_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  filename         = "lambda_functions/verify_transaction.zip"
  source_code_hash = filebase64sha256("lambda_functions/verify_transaction.zip")
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      BLOCKCHAIN_NETWORK   = var.blockchain_network
      RPC_ENDPOINT         = var.rpc_endpoint
      CONFIRMATION_BLOCKS  = var.confirmation_blocks[var.blockchain_network]
      DYNAMODB_TABLE       = aws_dynamodb_table.blockchain_transactions.name
    }
  }

  tags = {
    Name        = "${var.app_name}-verify-transaction"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}

resource "aws_lambda_function" "get_transaction" {
  function_name    = "${var.app_name}-get-transaction"
  role             = aws_iam_role.blockchain_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  filename         = "lambda_functions/get_transaction.zip"
  source_code_hash = filebase64sha256("lambda_functions/get_transaction.zip")
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      BLOCKCHAIN_NETWORK = var.blockchain_network
      RPC_ENDPOINT       = var.rpc_endpoint
      EXPLORER_BASE_URL  = var.explorer_base_url[var.blockchain_network]
      DYNAMODB_TABLE     = aws_dynamodb_table.blockchain_transactions.name
    }
  }

  tags = {
    Name        = "${var.app_name}-get-transaction"
    Environment = "production"
    Blockchain  = var.blockchain_network
  }
}