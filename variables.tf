variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "spiffe_trust_domain" {
  description = "The SPIFFE Trust domain/Audience prefix"
  type        = string
  default     = "example.org"
}