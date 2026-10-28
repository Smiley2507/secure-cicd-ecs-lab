resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  # Publishes RunningTaskCount and per-service CPU/memory, which the
  # ecs-alarms module reads.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- bootstrap task definition ---------------------------------------------
# The service needs *some* task definition to be created, but the ECR repo is
# empty until the first pipeline run. This placeholder answers /health with a
# 200 so the ALB marks it healthy; the first Jenkins build replaces it.
#
# It lives in its own family on purpose: the pipeline's cleanup step
# deregisters old revisions of the app's family, and must never touch a
# revision Terraform is tracking.
resource "aws_ecs_task_definition" "bootstrap" {
  family                   = "${var.service_name}-bootstrap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = var.container_name
    image     = "public.ecr.aws/docker/library/python:3.12-alpine"
    essential = true
    command = [
      "sh", "-c",
      "mkdir -p /srv && echo ok > /srv/health && cd /srv && exec python -m http.server ${var.container_port}",
    ]
    portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = var.region
        awslogs-stream-prefix = "bootstrap"
      }
    }
  }])
}

resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.bootstrap.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Rolling update: start the new tasks before stopping the old ones, so
  # capacity never drops below desired_count during a deploy.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # If the new revision never becomes healthy, ECS stops the rollout and puts
  # the last good revision back.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  propagate_tags = "SERVICE"

  # Jenkins owns the task definition after the first deploy. Without this,
  # every `terraform apply` would roll the service back to the placeholder.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
