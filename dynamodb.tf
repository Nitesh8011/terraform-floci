resource "aws_dynamodb_table" "first-dynamodb" {
  name         = "first-dynamodb-table"
  hash_key     = "TestTableHashKey"
  billing_mode = "PAY_PER_REQUEST"
  #   stream_enabled = true
  #   stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "TestTableHashKey"
    type = "S"
  }
  #   replica {
  #     region_name      = var.region
  #     consistency_mode = "STRONG"
  #   }

  #   replica {
  #     region_name      = "us-east-2"
  #     consistency_mode = "STRONG"
  #   }

}