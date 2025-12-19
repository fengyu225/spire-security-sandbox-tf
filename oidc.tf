locals {
  s3_host = "${local.bucket_name}.s3.${data.aws_region.current.name}.amazonaws.com"
}

data "tls_certificate" "s3" {
  url = "https://${local.s3_host}"
}

data "tls_certificate" "oidc" {
  url = "https://${aws_cloudfront_distribution.oidc.domain_name}"
}

resource "aws_iam_openid_connect_provider" "spire" {
  url = "https://${aws_cloudfront_distribution.oidc.domain_name}"

  client_id_list = [
    "SPIFFE/${var.spiffe_trust_domain}",
    "sts.amazonaws.com"
  ]

  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}