# resource "aws_iam_role" "bypass" {
#   name = "BypassSpireRole"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = module.eks.oidc_provider_arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${module.eks.oidc_provider}:sub" = "system:serviceaccount:app:bypass-workload",
#             "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
#           }
#         }
#       }
#     ]
#   })
# }
#
# resource "aws_iam_role_policy" "bypass_allow" {
#   name = "AllowRDSConnect"
#   role = aws_iam_role.bypass.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "rds-db:connect"
#         ]
#         Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.default.resource_id}/testuser"
#       }
#     ]
#   })
# }