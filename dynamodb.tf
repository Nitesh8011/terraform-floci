variable "table_names" {
  type    = list(string)
  default = ["orders", "users", "sessions"]
}

resource "aws_dynamodb_table" "tables" {
  for_each     = toset(var.table_names)
  name         = "${each.value}-table"
  hash_key     = "id"
  billing_mode = var.dynamodb_billing_mode
  region       = var.region

  #   stream_enabled = true
  #   stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "id"
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