resource "aws_iam_role" "lambda_exec" {
  name               = "photoUploadRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17","Statement":[
    {"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambdaS3ReadWrite"
  role   = aws_iam_role.lambda_exec.id
  policy = <<EOF
{
  "Version": "2012-10-17","Statement":[
    {"Effect": "Allow", "Action": ["s3:*"], 
     "Resource": ["${aws_s3_bucket.frontend_bucket.arn}/*"]}
  ]
}
EOF
}

data "archive_file" "upload_files" {
  type        = "zip"
  source_dir  = "${path.module}/upload_files"
  output_path = "${path.module}/upload_files.zip"
}

data "archive_file" "list_files" {
  type        = "zip"
  source_dir  = "${path.module}/list_files"
  output_path = "${path.module}/list_files.zip"
}


resource "aws_lambda_function" "uploader" {
  depends_on = [data.archive_file.upload_files]

  function_name    = "photo_upload"
  runtime          = "python3.13"
  handler          = "main.lambda_handler"
  filename         = data.archive_file.upload_files.output_path
  source_code_hash = data.archive_file.upload_files.output_base64sha256
  timeout          = 60
  role             = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.frontend_bucket.bucket
    }
  }
}

resource "aws_lambda_function" "list_files" {
  depends_on = [data.archive_file.list_files]

  function_name    = "list_files"
  runtime          = "python3.13"
  handler          = "main.lambda_handler"
  filename         = data.archive_file.list_files.output_path
  source_code_hash = data.archive_file.list_files.output_base64sha256
  timeout          = 60
  role             = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.frontend_bucket.bucket
    }
  }
}


resource "aws_lambda_function_url" "uploader" {
  function_name      = aws_lambda_function.uploader.function_name
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["*"]
  }
}

resource "aws_lambda_function_url" "list_files" {
  function_name      = aws_lambda_function.list_files.function_name
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["*"]
  }
}

resource "aws_lambda_permission" "uploader" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.uploader.function_name
  principal              = "*"
  function_url_auth_type = "NONE" # TEMPORARY!
}

resource "aws_lambda_permission" "list_files" {
  statement_id           = "FunctionURLAllowPublicAccessListFiles"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.list_files.function_name
  principal              = "*"
  function_url_auth_type = "NONE" # TEMPORARY!
}

resource "aws_cloudwatch_log_group" "uploader" {
  name              = "/aws/lambda/${aws_lambda_function.uploader.function_name}"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "list_files" {
  name              = "/aws/lambda/${aws_lambda_function.list_files.function_name}"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "cognito_auth" {
  provider = aws.us_east_1
  
  name              = "/aws/lambda/${aws_lambda_function.cognito_auth.function_name}"
  retention_in_days = 1
}

data "archive_file" "cognito_auth" {
  type        = "zip"
  source_dir  = "${path.module}/cognito_auth"
  output_path = "${path.module}/cognito_auth.zip"
}

resource "aws_iam_role" "cognito_auth" {
  name = "lambda-edge-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Add SSM Parameter access policy
resource "aws_iam_role_policy" "cognito_auth_ssm" {
  name = "ssm-parameter-access"
  role = aws_iam_role.cognito_auth.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter"
        ],
        Resource = [
          "arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter/cloudarchive/cognito/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cognito_auth" {
  role       = aws_iam_role.cognito_auth.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "cognito_auth" {
  provider = aws.us_east_1

  function_name    = "cognito-auth"
  filename         = data.archive_file.cognito_auth.output_path
  source_code_hash = data.archive_file.cognito_auth.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.9"
  role             = aws_iam_role.cognito_auth.arn
  publish          = true
}