variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "billing_mode" {
  description = "Dynamodb Billing mode"
  type        = string
}

variable "table_names" {
  type = list(string)
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

variable "sqs_name" {
  type = list(string)

}