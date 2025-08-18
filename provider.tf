provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket       = "terraformbackendbartd"
    key          = "cloudarchive.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
