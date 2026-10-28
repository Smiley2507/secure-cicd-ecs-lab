variable "name" {
  description = "Prefix for the ALB and target group names"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "At least two subnets in different AZs"
  type        = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "target_port" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/health"
}
