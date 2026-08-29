data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "module_bucket" {
  bucket = format("%s-%s-%s-%s", var.bucket_name, terraform.workspace, data.aws_caller_identity.current.account_id, var.region)
  region = var.region
}

resource "aws_s3_bucket_versioning" "module_bucket_versioning" {
  bucket = aws_s3_bucket.module_bucket.id
  versioning_configuration {
    status = var.version_status
  }
}