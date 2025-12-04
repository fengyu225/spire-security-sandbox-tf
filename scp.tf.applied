# --------------------------------------------------------------------------------
# SCP 1: Immutable IAM (The "Lock")
# --------------------------------------------------------------------------------
# This prevents ANYONE (Console users, other roles) from creating/editing IAM.
# Only the "TFC-Admin-Role" is allowed to bypass this.
resource "aws_organizations_policy" "immutable_iam" {
  name        = "SCP-Enforce-Terraform-IAM"
  description = "Restricts IAM Write operations to the TFC Automation Role only."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMChangesExceptTFC"
        Effect = "Deny"
        Action = [
          "iam:Create*", "iam:Delete*", "iam:Update*",
          "iam:Put*", "iam:Attach*", "iam:Detach*",
          "iam:Tag*", "iam:Untag*"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/TFC-Admin-Role",    # Allow TFC
              "arn:aws:iam::*:role/aws-service-role/*" # Allow AWS Services
            ]
          }
        }
      }
    ]
  })
}

# --------------------------------------------------------------------------------
# SCP 2: Pipeline Integrity
# --------------------------------------------------------------------------------
# This prevents anyone from deleting or modifying the TFC Role itself.
# If someone deleted this role, pipeline would break.
resource "aws_organizations_policy" "protect_pipeline_role" {
  name        = "SCP-Protect-TFC-Role"
  description = "Prevents modification or deletion of the Critical TFC Admin Role."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyTamperingWithTFCRole"
        Effect = "Deny"
        Action = [
          "iam:DeleteRole", "iam:DeleteRolePolicy",
          "iam:UpdateAssumeRolePolicy", "iam:UpdateRole"
        ]
        Resource = ["arn:aws:iam::*:role/TFC-Admin-Role"]
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:role/TFC-Admin-Role"
          }
        }
      }
    ]
  })
}

# --------------------------------------------------------------------------------
# SCP 3: Security Baseline
# --------------------------------------------------------------------------------
# Prevents disabling CloudTrail or GuardDuty.
resource "aws_organizations_policy" "security_baseline" {
  name        = "SCP-Security-Baseline"
  description = "Protects logging and auditing configurations."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:role/TFC-Admin-Role"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "attach_immutable_iam" {
  policy_id = aws_organizations_policy.immutable_iam.id
  target_id = var.sandbox_ou_id
}

resource "aws_organizations_policy_attachment" "attach_pipeline_protect" {
  policy_id = aws_organizations_policy.protect_pipeline_role.id
  target_id = var.sandbox_ou_id
}

resource "aws_organizations_policy_attachment" "attach_baseline" {
  policy_id = aws_organizations_policy.security_baseline.id
  target_id = var.sandbox_ou_id
}