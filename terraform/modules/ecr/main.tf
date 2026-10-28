resource "aws_ecr_repository" "this" {
  name = var.name

  # A tag, once pushed, always means the same image. The pipeline tags with
  # BUILD_NUMBER-SHORT_SHA, so a rebuild can never silently replace what a
  # task definition revision points at.
  image_tag_mutability = "IMMUTABLE"

  # AWS's own basic scan, as a second opinion next to Trivy in the pipeline.
  image_scanning_configuration {
    scan_on_push = true
  }

  # Lets `terraform destroy` remove the repository with images still in it.
  force_delete = var.force_delete
}

# The "clean up old images" requirement. Rules are evaluated by priority, and
# a tagStatus = "any" rule must have the highest number.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} day(s)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the ${var.keep_image_count} most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_image_count
        }
        action = { type = "expire" }
      },
    ]
  })
}
