locals {
  bucket_name = "spire-oidc-${data.aws_caller_identity.current.account_id}"
  oidc_url    = "https://${local.bucket_name}.s3.${data.aws_region.current.name}.amazonaws.com"
}

resource "aws_s3_bucket" "oidc" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "oidc" {
  bucket = aws_s3_bucket.oidc.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "oidc" {
  bucket = aws_s3_bucket.oidc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.oidc.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.oidc.arn
          }
        }
      },
      {
        Sid    = "AllowSpireServerPublish"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.spire_server.arn
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.oidc.arn,
          "${aws_s3_bucket.oidc.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_object" "openid_config" {
  bucket       = aws_s3_bucket.oidc.id
  key          = ".well-known/openid-configuration"
  content_type = "application/json"

  # DYNAMIC URL: We now point to the CloudFront domain
  content = jsonencode({
    issuer                                = "https://${aws_cloudfront_distribution.oidc.domain_name}"
    jwks_uri                              = "https://${aws_cloudfront_distribution.oidc.domain_name}/keys"
    authorization_endpoint                = ""
    response_types_supported              = ["id_token"]
    subject_types_supported               = []
    id_token_signing_alg_values_supported = ["RS256", "ES256", "ES384"]
  })
}

# ===========================================
# SPIRE Credential Authorization Bucket
# ===========================================
locals {
  rules_bucket_name    = "spire-auth-rules-${data.aws_caller_identity.current.account_id}"
  workload_spiffe_path = "example.org/ns/app/sa/test-workload"
}

resource "aws_s3_bucket" "rules" {
  bucket = local.rules_bucket_name
}

resource "aws_s3_object" "test_workload_rule" {
  bucket       = aws_s3_bucket.rules.id
  key          = local.workload_spiffe_path
  content_type = "application/json"

  content = jsonencode([
    {
      spiffe_id      = "spiffe://${local.workload_spiffe_path}"
      aws_account_id = data.aws_caller_identity.current.account_id
      db_type        = "aurora"
      db_cluster     = "checkout-db"
      db_user        = "read-only-user-1"
    },
    {
      spiffe_id      = "spiffe://${local.workload_spiffe_path}"
      aws_account_id = data.aws_caller_identity.current.account_id
      db_type        = "aurora"
      db_cluster     = "payment-db"
      db_user        = "read-write-user-1"
    },
    {
      spiffe_id      = "spiffe://${local.workload_spiffe_path}"
      aws_account_id = data.aws_caller_identity.current.account_id
      db_type        = "rds"
      db_cluster     = aws_db_instance.default.resource_id
      db_user        = "testuser"
    }
  ])
}

# Allow the SpireServerRole to READ from this bucket
resource "aws_iam_role_policy" "spire_server_read_rules" {
  name = "SpireServerReadRules"
  role = aws_iam_role.spire_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.rules.arn,
          "${aws_s3_bucket.rules.arn}/*"
        ]
      }
    ]
  })
}