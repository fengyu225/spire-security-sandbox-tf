resource "aws_cloudfront_origin_access_control" "oidc" {
  name                              = "spire-oidc-oac"
  description                       = "OAC for SPIRE OIDC S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "oidc" {
  origin {
    domain_name              = aws_s3_bucket.oidc.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oidc.id
    origin_id                = "S3-SPIRE-OIDC"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "SPIRE OIDC Provider"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-SPIRE-OIDC"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 3600
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}