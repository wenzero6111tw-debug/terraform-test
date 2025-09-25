# iam-sso 模块

输出组织级 IAM 权限边界策略，并为后续集成 AWS IAM Identity Center 预留扩展点。

- `permission_boundary_policy_json`：传入自定义权限边界策略。
- `sso_permission_sets`：可扩展管理 SSO 权限集。

根据需要在此模块中新增跨账号角色、权限边界应用和信任策略模板。
