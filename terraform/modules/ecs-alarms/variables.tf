variable "name" {
  description = "Prefix for the alarm names"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "desired_count" {
  description = "RunningTaskCount below this trips the alarm"
  type        = number
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "max_5xx_per_5min" {
  type    = number
  default = 5
}

variable "alarm_actions" {
  description = "ARNs notified on ALARM and OK (e.g. an SNS topic). Empty: state changes are visible in the console only."
  type        = list(string)
  default     = []
}
