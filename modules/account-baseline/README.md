# account-baseline 模块

提供 AWS 组织层面的安全与审计基线，包括：

- AWS Organizations 初始化（可选）。
- 组织级 CloudTrail、S3 审计桶与 KMS 密钥。
- GuardDuty、Security Hub 启用。
- 月度预算示例。

在上层 Stack 中引用时，请为 `audit_account_id`、`security_account_id` 等变量提供实际值，并根据组织规范覆盖标签。
