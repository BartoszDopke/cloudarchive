resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "photoarchivebucket"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "frontend_bucket" {
  depends_on = [aws_s3_bucket_public_access_block.frontend_bucket]

  bucket = aws_s3_bucket.frontend_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "frontend_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.frontend_bucket]

  bucket = aws_s3_bucket.frontend_bucket.id
  acl    = "public-read"
}

resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.frontend_bucket.id
  key    = "index.html"
  content = replace(
    file("frontend/index.html"),
    "lambda_function_url",
    aws_lambda_function_url.uploader.function_url
  )
  content_type = "text/html"
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  depends_on = [aws_s3_bucket_public_access_block.frontend_bucket]

  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}

# resource "aws_s3_bucket_lifecycle_configuration" "archive" {
#   bucket = aws_s3_bucket.frontend_bucket.id

#   rule {
#     id = "immediately-archive"

#     filter {
#       prefix = "images/"
#       and {
#         object_size_greater_than = 131072
#         prefix                   = "images/"
#       }
#     }
#     status = "Enabled"

#     transition {
#       days          = 1
#       storage_class = "GLACIER"
#     }
#   }
# }

output "website_url" {
  value = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
}