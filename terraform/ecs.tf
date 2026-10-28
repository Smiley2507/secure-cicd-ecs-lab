# Cluster + Fargate service. Terraform creates the service on a placeholder
# task definition; from the first pipeline run on, Jenkins registers the real
# revisions and Terraform ignores which one the service points at.

module "ecs" {
  source = "./modules/ecs-service"

  cluster_name   = "${var.project}-cluster"
  service_name   = var.app_name
  container_name = var.app_name
  container_port = var.container_port
  desired_count  = var.desired_count
  task_cpu       = var.task_cpu
  task_memory    = var.task_memory

  execution_role_arn = module.ecs_task_roles.execution_role_arn
  task_role_arn      = module.ecs_task_roles.task_role_arn
  log_group_name     = module.app_logs.name
  region             = var.region

  subnet_ids         = module.network.public_subnet_ids
  security_group_ids = [module.tasks_sg.security_group_id]
  assign_public_ip   = true # no NAT gateway; see network.tf
  target_group_arn   = module.alb.target_group_arn
}
