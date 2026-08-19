variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "floci-bucket"
}

variable "dynamodb_table" {
  description = "Dynamodb table name"
  type        = string
}

variable "dynamodb_billing_mode" {
  description = "Dynamodb billing mode"
  type        = string
}