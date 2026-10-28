output "name" {
  value = aws_lb.this.name
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "arn_suffix" {
  description = "The LoadBalancer dimension for CloudWatch metrics"
  value       = aws_lb.this.arn_suffix
}

# An ECS service cannot attach to a target group that no load balancer
# forwards to yet. Tying the output to the listener makes anything that
# consumes it wait for the listener too.
output "target_group_arn" {
  value      = aws_lb_target_group.this.arn
  depends_on = [aws_lb_listener.http]
}

output "target_group_arn_suffix" {
  description = "The TargetGroup dimension for CloudWatch metrics"
  value       = aws_lb_target_group.this.arn_suffix
}
