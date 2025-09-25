# Infracost 本地估算
> LocalStack 不计费，但你可以用 Infracost 预估“如果部署到真实 AWS”的成本。

1) 安装 CLI 并配置 token（免费账号）
```bash
infracost auth login
```

2) 生成估算
```bash
infracost breakdown --path infracost/infracost.yml
```

3) 在 CI 中使用
- 对 PR 运行 `terraform plan`
- 用 `infracost comment` 把成本 diff 贴回 PR
