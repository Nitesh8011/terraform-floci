output "module_dynamodb_table_arn" {
  value = [for t in aws_dynamodb_table.module_dynamodb_table : t.arn]
}

output "module_dynamodb_table_name" {
  value = [for t in aws_dynamodb_table.module_dynamodb_table : t.name]
}