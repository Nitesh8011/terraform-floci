# s3 bucket info
region      = "us-east-1"
bucket_name = "floci"

# dynamodb info
billing_mode = "PROVISIONED"
table_names  = ["orders", "users", "sessions", "audit-log"]

# sqs into
sqs_name                         = ["orders", "users", "sessions", "audit-log"]
module_max_message_size          = 4096
module_delay_seconds             = "180"
module_message_retention_seconds = 86400
module_receive_wait_time_seconds = 30