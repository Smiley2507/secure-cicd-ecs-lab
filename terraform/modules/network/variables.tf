variable "name" {
  description = "Prefix for resource Name tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "One public subnet per AZ"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs for the public subnets, same order as public_subnet_cidrs"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone is required."
  }
}
