# No long-lived access keys anywhere:
#   ecs_task_roles - execution role (image pull, logs) + task role (the app)
#   jenkins_role   - instance profile for the CI host: push + deploy

module "ecs_task_roles" {
  source = "./modules/ecs-task-roles"

  name_prefix = var.project
}

# What the pipeline is allowed to do, scoped to this lab's resources wherever
# the API supports resource-level permissions.
data "aws_iam_policy_document" "jenkins" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushThisRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr.repository_arn]
  }

  # Task definition actions do not support resource-level restrictions.
  statement {
    sid = "TaskDefinitions"
    actions = [
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DeployThisService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [module.ecs.service_arn]
  }

  # Registering a task definition that names these roles requires PassRole on
  # them — and only them, and only to ECS.
  statement {
    sid     = "PassTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      module.ecs_task_roles.execution_role_arn,
      module.ecs_task_roles.task_role_arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # The smoke test looks up the ALB's DNS name instead of hardcoding it.
  statement {
    sid       = "FindTheAlb"
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }

  # CloudWatch agent shipping /var/log/jenkins/jenkins.log.
  statement {
    sid = "JenkinsLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${module.jenkins_logs.arn}:*"]
  }
}

module "jenkins_role" {
  source = "./modules/instance-role"

  name        = "${var.project}-jenkins"
  policy_json = data.aws_iam_policy_document.jenkins.json

  # Shell access through Session Manager, as a fallback to SSH.
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}
