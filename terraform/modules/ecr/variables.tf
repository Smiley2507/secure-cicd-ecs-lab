variable "name" {
  type = string
}

variable "keep_image_count" {
  type    = number
  default = 10
}

variable "untagged_expiry_days" {
  type    = number
  default = 1
}

variable "force_delete" {
  type    = bool
  default = true
}
