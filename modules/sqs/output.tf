output "queue_name" {
  value = [for q in aws_sqs_queue.floci_queue : q.name]
}


output "queue_arn" {
  value = [for q in aws_sqs_queue.floci_queue : q.arn]
}

output "queue_arn_by_name" {
  value = { for k, q in aws_sqs_queue.floci_queue : k => q.arn }
}