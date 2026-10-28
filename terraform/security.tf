# Three security groups, chained by reference rather than by CIDR:
#   internet -> ALB :80 -> tasks :8000
# The tasks have public IPs (no NAT), so the SG reference is what keeps them
# unreachable except through the load balancer.
#
# alb_sg and tasks_sg reference each other. That is not a cycle: each group is
# created first, and only the rules depend on the other group's ID.

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

  # ECR, CloudWatch Logs and Open-Meteo are all HTTPS.
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
      cidr_ipv4             = var.admin_cidr
    }
  ]

  # Jenkins pulls scanner images, pushes to ECR, calls the AWS APIs and curls
  # the ALB for the smoke test — unrestricted egress is the honest description.
  egress_rules = [{
    description = "All outbound"
    ip_protocol = "-1"
    cidr_ipv4   = "0.0.0.0/0"
  }]
}
