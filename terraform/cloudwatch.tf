module "app_logs" {
  source = "./modules/log-group"

  name              = "/ecs/${var.app_name}"
  retention_in_days = var.log_retention_days
}

module "jenkins_logs" {
  source = "./modules/log-group"

  name              = "/jenkins/system"
  retention_in_days = var.log_retention_days
}

module "alarms" {
  source = "./modules/ecs-alarms"

  name                    = "${var.project}-${var.app_name}"
  cluster_name            = module.ecs.cluster_name
  service_name            = module.ecs.service_name
  desired_count           = var.desired_count
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
}
