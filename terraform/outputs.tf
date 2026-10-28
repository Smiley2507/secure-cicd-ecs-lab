output "jenkins_url" {
  value = "http://${module.jenkins.public_ip}:8080"
}

output "sonarqube_url" {
  value = "http://${module.jenkins.public_ip}:9000"
}

output "app_url" {
  description = "The ALB — where the deployed app is reachable"
  value       = "http://${module.alb.dns_name}"
}

output "ssh_jenkins" {
  value = "ssh -i ${module.key_pair.private_key_path} ec2-user@${module.jenkins.public_ip}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "alarm_names" {
  value = module.alarms.alarm_names
}

# Everything the pipeline needs, for cross-checking against the names the
# Jenkinsfile derives on its own.
output "pipeline_env" {
  value = {
    AWS_REGION    = var.region
    ECR_REPO      = module.ecr.repository_url
    ECS_CLUSTER   = module.ecs.cluster_name
    ECS_SERVICE   = module.ecs.service_name
    TASK_FAMILY   = var.app_name
    EXEC_ROLE_ARN = module.ecs_task_roles.execution_role_arn
    TASK_ROLE_ARN = module.ecs_task_roles.task_role_arn
    LOG_GROUP     = module.app_logs.name
    ALB_NAME      = module.alb.name
  }
}
