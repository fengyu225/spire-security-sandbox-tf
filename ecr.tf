resource "aws_ecr_repository" "plugin" {
  name                 = "spire-aws-auth-plugin"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "plugin_policy" {
  repository = aws_ecr_repository.plugin.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 30
      }
      action = {
        type = "expire"
      }
    }]
  })
}