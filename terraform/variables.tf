variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Named profile in ~/.aws/credentials used for this deployment"
  type        = string
  default     = "sandbox-user"
}

variable "project" {
  description = "Prefix used for resource names. The Jenkinsfile derives role, cluster and service names from it, so change both together."
  type        = string
  default     = "secure-cicd"
}

variable "app_name" {
  description = "ECR repository, container and ECS service name"
  type        = string
  default     = "weather-app"
}

# --- network ---------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per AZ. An ALB needs at least two AZs."
  type        = list(string)
  default     = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "availability_zones" {
  description = "AZs for the public subnets, same order as public_subnet_cidrs"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

# --- ECS -------------------------------------------------------------------

variable "container_port" {
  description = "Port gunicorn listens on inside the container"
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Number of Fargate tasks behind the ALB"
  type        = number
  default     = 2
}

variable "task_cpu" {
  default = 256
}

variable "task_memory" {
  default = 512
}

# --- Jenkins host ----------------------------------------------------------

variable "jenkins_instance_type" {
  description = "Jenkins and SonarQube share this host. SonarQube alone wants ~3 GB, hence t3.large."
  type        = string
  default     = "t3.large"
}

variable "jenkins_root_volume_size" {
  description = "Docker images for every scanner, the Trivy DB and SonarQube data all land here"
  type        = number
  default     = 30
}

variable "ami_id" {
  description = "Pinned AL2023 AMI (eu-west-1). Resolving the latest at plan time makes every plan want to replace the instance."
  type        = string
  default     = "ami-0cbe64e51c016e5bf"
}

# --- access ----------------------------------------------------------------

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH, Jenkins and SonarQube. Set to your IP/32 in terraform.tfvars."
  type        = string
}

variable "private_key_path" {
  description = "Local path where the generated private key is written. Consumed by Ansible."
  type        = string
  default     = "./secure-cicd-key.pem"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  description = "Default tags applied to every resource"
  type        = map(string)
  default = {
    Project     = "secure-cicd-ecs-lab"
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}
