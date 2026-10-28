# Created by Terraform rather than on first write, so retention is set from
# day one instead of the default "never expire".
resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_in_days
}
