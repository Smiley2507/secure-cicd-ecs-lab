variable "name" {
  description = "Name of the role and of the instance profile"
  type        = string
}

variable "policy_json" {
  description = "Inline policy document attached to the role"
  type        = string
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}
