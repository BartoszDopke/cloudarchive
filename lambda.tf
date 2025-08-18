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
  name   = "lambdaS3Write"
  role   = aws_iam_role.lambda_exec.id
  policy = <<EOF
{
  "Version": "2012-10-17","Statement":[
    {"Effect": "Allow", "Action": ["s3:PutObject"], 
     "Resource": ["${aws_s3_bucket.frontend_bucket.arn}/*"]}
  ]
}
EOF
}

data "archive_file" "backend" {
  type        = "zip"
  source_dir  = "${path.module}/backend"
  output_path = "${path.module}/lambda_deployment.zip"
}


resource "aws_lambda_function" "uploader" {
  depends_on = [ data.archive_file.backend ]

  function_name    = "photo_upload_fn"
  runtime          = "python3.13"
  handler          = "main.lambda_handler"
  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256
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

resource "aws_lambda_permission" "uploader" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.uploader.function_name
  principal              = "*"
  function_url_auth_type = "NONE" # TEMPORARY!
}

resource "aws_cloudwatch_log_group" "uploader" {
  name              = "/aws/lambda/${aws_lambda_function.uploader.function_name}"
  retention_in_days = 1
}

output "function_url" {
  value = aws_lambda_function_url.uploader.function_url
}