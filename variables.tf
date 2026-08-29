variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "module-s3-bucket"
}

variable "billing_mode" {
  description = "Dynamodb Billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "table_names" {
  type    = list(string)
  default = ["module-table-1", "module-table-2", "module-table-3"]
}

variable "module_delay_seconds" {
  type = string
}

variable "module_max_message_size" {
  type = string
}

variable "module_message_retention_seconds" {
  type = string
}

variable "module_receive_wait_time_seconds" {
  type = string
}