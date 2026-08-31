# s3 bucket info
region      = "us-east-2"
bucket_name = "floci"

# dynamodb info
billing_mode = "PAY_PER_REQUEST"
table_names  = ["users", "sessions", "audit-log"]

# sqs into
sqs_name                         = ["user", "sessions", "audit-log"]
module_delay_seconds             = "90"
module_max_message_size          = 2048
module_message_retention_seconds = 86400
module_receive_wait_time_seconds = 10
upload_queue_name = "sessions"
