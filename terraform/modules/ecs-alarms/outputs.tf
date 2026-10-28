output "alarm_names" {
  value = [
    aws_cloudwatch_metric_alarm.running_tasks.alarm_name,
    aws_cloudwatch_metric_alarm.target_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name,
  ]
}
