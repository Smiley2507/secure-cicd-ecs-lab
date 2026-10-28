variable "name" {
  type = string
}

variable "ami_id" {
  description = "Pinned AMI. Resolving the latest at plan time makes every plan want to replace the instance."
  type        = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "iam_instance_profile" {
  type    = string
  default = null
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "tags" {
  description = "Extra tags, e.g. the Role tag the Ansible inventory groups by"
  type        = map(string)
  default     = {}
}
