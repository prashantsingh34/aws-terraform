provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_role" {
  name               = "terraform_aws_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for logging from a lambda

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

# Generates an archive from content, a file, or a directory of files.

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/python/"
  output_path = "${path.module}/python/test_handler.zip"
}

# Create a lambda function
# In terraform ${path.module} is the current directory.
resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "${path.module}/python/test_handler.zip"
  function_name = "lambda-from-terraform"
  role          = aws_iam_role.lambda_role.arn
  handler       = "test_handler.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}


output "teraform_aws_role_output" {
  value = aws_iam_role.lambda_role.name
}

output "teraform_aws_role_arn_output" {
  value = aws_iam_role.lambda_role.arn
}

output "teraform_logging_arn_output" {
  value = aws_iam_policy.iam_policy_for_lambda.arn
}

# # API Gateway REST API
resource "aws_api_gateway_rest_api" "testhandler_api" {
  name        = "testhandler_api"
  description = "Test handler API Gateway"
}

# # API Gateway Resource
resource "aws_api_gateway_resource" "testhandler_resource" {
  rest_api_id = aws_api_gateway_rest_api.testhandler_api.id
  parent_id   = aws_api_gateway_rest_api.testhandler_api.root_resource_id
  path_part   = "resthandler"
}

# # API Gateway Method
resource "aws_api_gateway_method" "testhandler_method" {
  rest_api_id   = aws_api_gateway_rest_api.testhandler_api.id
  resource_id   = aws_api_gateway_resource.testhandler_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integration between API Gateway and Lambda function
resource "aws_api_gateway_integration" "testhandler_integration" {
  rest_api_id = aws_api_gateway_rest_api.testhandler_api.id
  resource_id = aws_api_gateway_resource.testhandler_resource.id
  http_method = aws_api_gateway_method.testhandler_method.http_method

  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.terraform_lambda_func.invoke_arn
}

# # Lambda permission to allow API Gateway to invoke Lambda function
resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.testhandler_api.execution_arn}/*/*"
}

# # Deploy API Gateway to a stage
resource "aws_api_gateway_deployment" "testhandler_deployment" {
  depends_on      = [aws_api_gateway_integration.testhandler_integration]
  rest_api_id     = aws_api_gateway_rest_api.testhandler_api.id
  stage_name      = "default"  
}
