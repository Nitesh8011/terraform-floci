data "aws_caller_identity" "current" {}

module "module_bucket_config" {
  source         = "./modules/s3_bucket"
  bucket_name    = format("%s-%s-%s", var.bucket_name, data.aws_caller_identity.current.account_id, var.region)
  region         = var.region
  version_status = "Enabled"
}


module "module_dynamodb_table_config" {
  source = "./modules/dynamodb_table"
  module_table_names = var.table_names
  module_billing_mode = var.billing_mode
  module_region = var.region
}