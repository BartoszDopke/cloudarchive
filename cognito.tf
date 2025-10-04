# user pool

resource "aws_cognito_user_pool" "pool" {
  name                     = "photoarchivepool"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true
    developer_only_attribute = false


    string_attribute_constraints {
      min_length = "8"
      max_length = "2048"
    }

  }
}


resource "aws_cognito_user_pool_client" "pool" {
  name            = "my-user-pool-client"
  user_pool_id    = aws_cognito_user_pool.pool.id
  generate_secret = true

  # These are the redirect URIs after login
  callback_urls = [
    "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
  ]

  # These are the redirect URIs after logout
  #   logout_urls = [
  #     "https://myapp.com/logout",
  #     "http://localhost:3000/logout"
  #   ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"] # could be "implicit" or "client_credentials"
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  supported_identity_providers = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "pool" {
  domain       = "cloudarchive-test"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_ssm_parameter" "domain_name" {
  provider = aws.us_east_1
  name     = "/cloudarchive/cognito/domain_name"
  type     = "String"
  value    = aws_cognito_user_pool.pool.domain
}

resource "aws_ssm_parameter" "client_secret" {
  provider = aws.us_east_1
  name     = "/cloudarchive/cognito/client_secret"
  type     = "SecureString"
  value    = aws_cognito_user_pool_client.pool.client_secret
}

resource "aws_ssm_parameter" "client_id" {
  provider = aws.us_east_1 # Use the us-east-1 provider
  name     = "/cloudarchive/cognito/client_id"
  type     = "String" # Client ID is not sensitive, so we can use String type
  value    = aws_cognito_user_pool_client.pool.id
}
