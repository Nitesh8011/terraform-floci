resource "aws_dynamodb_table" "module_dynamodb_table" {
  for_each     = toset(var.module_table_names)
  name         = "${each.value}-${var.module_name_suffix}-table"
  hash_key     = "ModuleTableHashKey"
  billing_mode = var.module_billing_mode
  region       = var.module_region

  attribute {
    name = "ModuleTableHashKey"
    type = "S"
  }
}