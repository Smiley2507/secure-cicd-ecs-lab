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

# ECS cannot attach a service to a target group with no listener yet; depends_on makes consumers wait for it.
output "target_group_arn" {
  value      = aws_lb_target_group.this.arn
  depends_on = [aws_lb_listener.http]
}

output "target_group_arn_suffix" {
  description = "The TargetGroup dimension for CloudWatch metrics"
  value       = aws_lb_target_group.this.arn_suffix
}
