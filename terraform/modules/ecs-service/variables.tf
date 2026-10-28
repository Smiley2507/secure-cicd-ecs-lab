variable "cluster_name" {
  type = string
}

variable "service_name" {
  description = "Also the prefix of the bootstrap task definition family"
  type        = string
}

variable "container_name" {
  description = "Must match the container name in the pipeline's task definition template"
  type        = string
}

variable "container_port" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  description = "Needed in public subnets without a NAT gateway, to pull from ECR"
  type        = bool
  default     = true
}

variable "target_group_arn" {
  type = string
}
