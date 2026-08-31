data "aws_caller_identity" "current" {}

locals {
  name_suffix = "floci-${data.aws_caller_identity.current.account_id}-${var.region}-${terraform.workspace}"
}

module "module_bucket_config" {
  source             = "./modules/s3_bucket"
  bucket_name        = "${var.bucket_name}-${local.name_suffix}-bucket"
  region             = var.region
  version_status     = "Enabled"
  module_name_suffix = local.name_suffix
}


module "module_dynamodb_table_config" {
  source              = "./modules/dynamodb_table"
  module_table_names  = var.table_names
  module_billing_mode = var.billing_mode
  module_region       = var.region
  module_name_suffix  = local.name_suffix
}


module "module_sqs_queue_config" {
  source                           = "./modules/sqs"
  module_bucket_arn                = module.module_bucket_config.arn
  module_sqs_name                  = var.sqs_name
  module_delay_seconds             = var.module_delay_seconds
  module_max_message_size          = var.module_max_message_size
  module_region                    = var.region
  module_message_retention_seconds = var.module_message_retention_seconds
  module_receive_wait_time_seconds = var.module_receive_wait_time_seconds
  module_name_suffix               = local.name_suffix
}

resource "aws_s3_bucket_notification" "bucket_upload_notification" {
  bucket = module.module_bucket_config.id

  queue {
    queue_arn = module.module_sqs_queue_config.queue_arn_by_name[var.upload_queue_name]
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [module.module_sqs_queue_config]
}