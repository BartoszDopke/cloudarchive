provider "aws" {
  region = var.aws_region
}

provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

terraform {
  backend "s3" {
    bucket       = "terraformbackendbartd"
    key          = "cloudarchive.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
