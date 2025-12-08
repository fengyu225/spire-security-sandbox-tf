resource "aws_iam_role" "spire_server" {
  name = "SpireServerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:spire:spire-server",
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "spire_server_s3" {
  name = "SpireServerS3Access"
  role = aws_iam_role.spire_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.oidc.arn,
          "${aws_s3_bucket.oidc.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "db_access" {
  name = "DatabaseAccessRole"

  # Trust Policy: OIDC Federation with Tag checks
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.spire.arn
        }
        Action = [
          "sts:AssumeRoleWithWebIdentity",
          "sts:TagSession",
          "sts:SetSourceIdentity"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/Target" = ["aurora", "rds"],
            "${local.s3_host}:aud"  = "SPIFFE/${var.spiffe_trust_domain}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "db_access_rds" {
  name = "AuroraAccess"
  role = aws_iam_role.db_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        # Dynamic Resource ARN based on Session Tags
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:$${aws:PrincipalTag/DB}/$${aws:PrincipalTag/DBuser}"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Target" = ["aurora", "rds"]
          }
        }
      }
    ]
  })
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name             = "ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "boundary_test_role" {
  name                 = "BoundaryTestRole"
  permissions_boundary = aws_iam_policy.mandatory_permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:app:boundary-test-sa",
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "boundary_test_policy" {
  name = "AllowEverything"
  role = aws_iam_role.boundary_test_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "rds:*"
        Resource = "*"
      }
    ]
  })
}