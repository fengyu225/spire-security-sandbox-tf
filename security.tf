resource "aws_iam_user" "auditor" {
  name = "security-auditor"
}

resource "aws_iam_access_key" "auditor_key" {
  user = aws_iam_user.auditor.name
}

resource "aws_iam_user_policy" "auditor_assume" {
  name = "AllowAssumeAuditRole"
  user = aws_iam_user.auditor.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Resource = [
        aws_iam_role.security_audit.arn,
        aws_iam_role.iam_operator.arn
      ]
    }]
  })
}

resource "aws_iam_role" "security_audit" {
  name = "SecurityAuditRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.auditor.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "iam_operator" {
  name = "IAMOperatorRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.auditor.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_user_login_profile" "auditor_console" {
  user                    = aws_iam_user.auditor.name
  password_reset_required = true
}

resource "aws_iam_role_policy_attachment" "iam_operator_full" {
  role       = aws_iam_role.iam_operator.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_role_policy_attachment" "audit_view_only" {
  role       = aws_iam_role.security_audit.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "audit_security_audit" {
  role       = aws_iam_role.security_audit.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}