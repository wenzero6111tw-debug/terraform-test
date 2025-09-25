resource "aws_iam_policy" "permission_boundary" {
  name        = "permission-boundary"
  description = "Org-wide permission boundary"
  policy      = var.permission_boundary_policy_json
}

# 如需配置 IAM Identity Center（SSO），可在此模块扩展 sso-admin 资源。
