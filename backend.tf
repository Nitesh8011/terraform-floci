data "aws_caller_identity" "current" {}

module "module_bucket_config" {
  source         = "./modules/s3_bucket"
  bucket_name    = var.bucket_name
  region         = var.region
  version_status = "Enabled"
}


module "module_dynamodb_table_config" {
  source              = "./modules/dynamodb_table"
  module_table_names  = var.table_names
  module_billing_mode = var.billing_mode
  module_region       = var.region
}


module "module_sqs_queue_config" {
  source                           = "./modules/sqs"
  module_sqs_name                  = var.sqs_name
  module_delay_seconds             = var.module_delay_seconds
  module_max_message_size          = var.module_max_message_size
  module_region                    = var.region
  module_message_retention_seconds = var.module_message_retention_seconds
  module_receive_wait_time_seconds = var.module_receive_wait_time_seconds
}