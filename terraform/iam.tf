module "ecs_task_roles" {
  source = "./modules/ecs-task-roles"

  name_prefix = var.project
}

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

  statement {
    sid       = "FindTheAlb"
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }

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

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}
