resource "aws_sqs_queue" "floci_queue" {
  for_each                  = toset(var.module_sqs_name)
  name                      = "${each.value}-${var.module_name_suffix}-queue.fifo"
  region                    = var.module_region
  fifo_queue                = true
  delay_seconds             = var.module_delay_seconds
  max_message_size          = var.module_max_message_size
  message_retention_seconds = var.module_message_retention_seconds
  receive_wait_time_seconds = var.module_receive_wait_time_seconds
}