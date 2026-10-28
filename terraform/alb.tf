module "alb" {
  source = "./modules/alb"

  name               = var.project
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
  security_group_ids = [module.alb_sg.security_group_id]
  target_port        = var.container_port
  health_check_path  = "/health"
}
