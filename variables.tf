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

variable "sandbox_ou_id" {
  type    = string
  default = "ou-2355-x5uevxt7"
}