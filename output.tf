output "s3_floci_bucket_info" {
  value = {
    arn         = aws_s3_bucket.first-floci-bucket.arn
    domain_name = aws_s3_bucket.first-floci-bucket.bucket_domain_name
    region      = aws_s3_bucket.first-floci-bucket.region
  }
}


output "first-dynamodb-name" {
  value = aws_dynamodb_table.first-dynamodb.name
}