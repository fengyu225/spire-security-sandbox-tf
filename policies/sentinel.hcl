policy "iam-safety" {
  source            = "./iam-safety.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "rds-iam-protection" {
  source            = "./rds-iam-protection.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "rds-tag-protection" {
  source            = "./rds-tag-protection.sentinel"
  enforcement_level = "hard-mandatory"
}