locals {
  s3_host = "${local.bucket_name}.s3.${data.aws_region.current.name}.amazonaws.com"
}

data "tls_certificate" "s3" {
  url = "https://${local.s3_host}"
}

resource "aws_iam_openid_connect_provider" "spire" {
  url = "https://${local.s3_host}"

  client_id_list = [
    "SPIFFE/${var.spiffe_trust_domain}"
  ]

  thumbprint_list = [data.tls_certificate.s3.certificates[0].sha1_fingerprint]
}