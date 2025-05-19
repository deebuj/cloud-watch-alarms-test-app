terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    region = "us-east-1"
    encrypt = true
    # These values will be provided via backend-config in CI/CD
    # bucket = "myappnetwork-terraform-state"
    # key    = "cloud-watch-alarms-test-app.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_iam_role" "lambda_role" {
  name = "cloud-watch-alarms-test-lambda-role"

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
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "cloud-watch-alarms-test-cloudwatch-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"  # PutMetricData doesn't support resource-level permissions
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "${aws_cloudwatch_log_group.lambda_logs.arn}:*",
          "${aws_cloudwatch_log_group.lambda_logs.arn}:*:*"
        ]
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../Lambda.Api/bin/Release/net8.0/linux-x64/publish"
  output_path = "lambda.zip"
  excludes    = terraform.workspace == "default" ? [] : ["*"]  # Exclude everything during destroy
}

resource "aws_lambda_function" "api" {
  filename         = "lambda.zip"
  function_name    = "cloud-watch-alarms-test"
  role            = aws_iam_role.lambda_role.arn
  handler         = "Lambda.Api"
  runtime         = "dotnet8"
  memory_size     = 256
  timeout         = 30
  source_code_hash = fileexists("lambda.zip") ? data.archive_file.lambda_zip.output_base64sha256 : null

  environment {
    variables = {
      ASPNETCORE_ENVIRONMENT = "Production"
    }
  }

  depends_on = [
    data.archive_file.lambda_zip
  ]
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "cloud-watch-alarms-test-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp               = "$context.identity.sourceIp"
      requestTime            = "$context.requestTime"
      protocol              = "$context.protocol"
      httpMethod            = "$context.httpMethod"
      resourcePath          = "$context.resourcePath"
      routeKey              = "$context.routeKey"
      status                = "$context.status"
      responseLength        = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  depends_on = [aws_cloudwatch_log_group.api_gw]
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.api.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "any" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/cloud-watch-alarms-test"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
