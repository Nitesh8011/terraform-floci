output "queue_name" {
  value = aws_sqs_queue.floci_queue.name
}


output "queue_arn" {
  value = aws_sqs_queue.floci_queue.arn
}