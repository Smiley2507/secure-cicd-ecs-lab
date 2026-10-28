variable "name_prefix" {
  description = "Roles are named <prefix>-ecs-task-execution and <prefix>-ecs-task. The Jenkinsfile derives the same names."
  type        = string
}

variable "task_role_policy_arns" {
  type    = list(string)
  default = []
}
