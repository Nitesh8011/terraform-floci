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
  default = "PAY_PER_REQUEST"
}

variable "table_names" {
  type = list(string)
  default = [ "module-table-1", "module-table-2", "module-table-3" ]
}