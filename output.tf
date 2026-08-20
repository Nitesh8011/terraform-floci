output "s3_floci_bucket_info" {
  value = {
    arn         = aws_s3_bucket.first-floci-bucket.arn
    domain_name = aws_s3_bucket.first-floci-bucket.bucket_domain_name
    region      = aws_s3_bucket.first-floci-bucket.region
  }
}


output "all-dynamodb-table-names" {
  value = [for t in aws_dynamodb_table.tables : t.name]
}