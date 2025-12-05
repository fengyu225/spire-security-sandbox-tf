resource "aws_iam_role" "unauthorized_role" {
  name = "UnauthorizedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "violation_policy" {
  name = "illegal-rds-connect"
  role = aws_iam_role.unauthorized_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BypassIAMAuth"
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "*"
      }
    ]
  })
}