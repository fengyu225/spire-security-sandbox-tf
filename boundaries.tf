resource "aws_iam_policy" "mandatory_permission_boundary" {
  name        = "MandatoryPermissionBoundary"
  description = "Boundary to prevent direct DB access, session tag injection, and role tag spoofing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Block Direct DB Access
      {
        Sid      = "DenyDirectRDSConnect"
        Effect   = "Deny"
        Action   = "rds-db:connect"
        Resource = "*"
      },

      # 2. Prevent Session Tag Injection via AssumeRole
      {
        Sid      = "DenySessionTagPassthrough"
        Effect   = "Deny"
        Action   = "sts:AssumeRole"
        Resource = "*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "aws:TagKeys" = ["DB", "DBuser", "Target"]
          }
        }
      },

      # 3. Block TagSession with protected tags
      {
        Sid      = "DenyTagSessionForDBTags"
        Effect   = "Deny"
        Action   = "sts:TagSession"
        Resource = "*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "aws:TagKeys" = ["DB", "DBuser", "Target"]
          }
        }
      },

      # 4. Prevent adding protected tags to IAM roles
      {
        Sid    = "DenyTaggingRolesWithProtectedTags"
        Effect = "Deny"
        Action = [
          "iam:TagRole",
          "iam:CreateRole"
        ]
        Resource = "*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "aws:TagKeys" = ["DB", "DBuser", "Target"]
          }
        }
      },

      # 5. Prevent removing protected tags (if they exist on approved roles)
      {
        Sid      = "DenyUntaggingProtectedTags"
        Effect   = "Deny"
        Action   = "iam:UntagRole"
        Resource = "*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "aws:TagKeys" = ["DB", "DBuser", "Target"]
          }
        }
      },

      # 6. Allow everything else
      {
        Sid      = "AllowOtherActions"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}