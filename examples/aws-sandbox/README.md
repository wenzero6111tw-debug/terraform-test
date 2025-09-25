# AWS 沙箱（低成本）

1. 复制 `backend.tf.example` → `stacks/dev/backend.tf`，指向你的 state 桶/锁表。
2. 构建 Lambda 包：`bash examples/aws-sandbox/lambda_hello/build.sh`
3. 初始化与计划：
   ```bash
   cd examples/aws-sandbox
   terraform init && terraform fmt -recursive && terraform validate
   terraform plan -var="budget_usd=5" -var="ttl_hours=24"
   ```
4. 执行：
   ```bash
   terraform apply -auto-approve
   ```
5. 验证：
   - VPC/子网创建成功，无 NAT 资源；
   - VPC 端点（S3/DDB）生效；
   - CloudTrail 在 S3 写入日志；
   - Lambda 每小时被 EventBridge 触发一次；
6. 清理：
   ```bash
   terraform destroy -auto-approve
   ```

> 建议：开启 **Budgets** 的 SNS/Email 通知；若要用 AWS Config，请将 `enable_config=true`，并保持只记录少量资源类型。
