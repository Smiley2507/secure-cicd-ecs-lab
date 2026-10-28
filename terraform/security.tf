data "http" "operator_ip" {
  url = "https://checkip.amazonaws.com"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && can(cidrhost("${chomp(self.response_body)}/32", 0))
      error_message = "Could not determine this machine's public IP from checkip.amazonaws.com. Set admin_cidr in terraform.tfvars instead."
    }
  }
}

locals {
  admin_cidr = coalesce(var.admin_cidr, "${chomp(data.http.operator_ip.response_body)}/32")
}

module "alb_sg" {
  source = "./modules/security-group"

  name        = "${var.project}-alb-sg"
  description = "Public HTTP to the load balancer"
  vpc_id      = module.network.vpc_id

  ingress_rules = [{
    description = "HTTP from anywhere"
    ip_protocol = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_ipv4   = "0.0.0.0/0"
  }]

  egress_rules = [{
    description                  = "Forward to the app containers"
    ip_protocol                  = "tcp"
    from_port                    = var.container_port
    to_port                      = var.container_port
    referenced_security_group_id = module.tasks_sg.security_group_id
  }]
}

module "tasks_sg" {
  source = "./modules/security-group"

  name        = "${var.project}-tasks-sg"
  description = "Fargate tasks: app port from the ALB only"
  vpc_id      = module.network.vpc_id

  ingress_rules = [{
    description                  = "App port from the ALB"
    ip_protocol                  = "tcp"
    from_port                    = var.container_port
    to_port                      = var.container_port
    referenced_security_group_id = module.alb_sg.security_group_id
  }]

  egress_rules = [{
    description = "HTTPS out: ECR pull, CloudWatch Logs, Open-Meteo"
    ip_protocol = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_ipv4   = "0.0.0.0/0"
  }]
}

module "jenkins_sg" {
  source = "./modules/security-group"

  name        = "${var.project}-jenkins-sg"
  description = "Jenkins and SonarQube host"
  vpc_id      = module.network.vpc_id

  ingress_rules = [
    for name, port in { ssh = 22, jenkins = 8080, sonarqube = 9000 } : {
      description           = "${name} from the operator"
      ip_protocol           = "tcp"
      from_port             = port
      to_port               = port
      cidr_ipv4             = local.admin_cidr
    }
  ]

  egress_rules = [{
    description = "All outbound"
    ip_protocol = "-1"
    cidr_ipv4   = "0.0.0.0/0"
  }]
}
