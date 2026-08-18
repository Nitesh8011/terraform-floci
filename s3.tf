data "aws_caller_identity" "current" {}


resource "aws_s3_bucket" "first-floci-bucket" {
  bucket           = format("%s-%s-%s-an", var.bucket_name, data.aws_caller_identity.current.account_id, var.region)
  bucket_namespace = "account-regional"
}


resource "aws_s3_bucket_versioning" "floci-bucket-versioning" {
  bucket = aws_s3_bucket.first-floci-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}