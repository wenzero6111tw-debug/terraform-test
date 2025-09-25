# LocalStack + Terraform 练习套件

## 前置
- Docker / Docker Compose
- Terraform >= 1.6
- （可选）k6、Infracost CLI

## 1) 启动 LocalStack
```bash
docker compose up -d
# 或：docker run -d --rm -p 4566:4566 --name localstack localstack/localstack
```

## 2) Terraform 初始化 & 计划
```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

## 3) 执行与验证
```bash
terraform apply -auto-approve
# 列出 S3 桶（localstack 内置 endpoint）
curl http://localhost:4566/ \
  | sed -n '1,120p'
```

## 4) 触发 Lambda（S3 事件）
向桶上传任意文件：
```bash
awslocal s3 cp ./README.md s3://tf-demo-bucket/README.md
# 查看 LocalStack 日志或 CloudWatch Logs 模拟（控制台输出）
```
> `awslocal` 来自 pip 包 `awscli-local`，也可用原生 awscli 并加 `--endpoint-url=http://localhost:4566`

## 5) k6 压测（可选）
```bash
k6 run k6/smoke.js
```

## 6) Infracost 成本估算（可选）
```bash
infracost breakdown --path infracost/infracost.yml
```

## 清理
```bash
terraform destroy -auto-approve
# 停止 LocalStack
docker compose down
```
