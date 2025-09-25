# Terraform 平台基线目录骨架（AWS）

> 目标：可直接复制为你的平台工程仓库雏形；先跑 **account-baseline → network-core → iam-sso**，再逐步上 **observability / cicd-foundation / 服务蓝图**。代码块内均含注释（`#`、`//`）。

---

## 目录结构（建议）
```text
aws-platform-terraform/
├─ README.md
├─ versions.tf                 # 全局 TF 版本约束
├─ providers.tf                # 可选：默认 provider（可在 stacks/* 层覆盖）
├─ backend.example.tf          # S3+DynamoDB 远端状态模板（复制到 stacks/* 使用）
├─ Makefile                    # 常用命令（fmt/validate/plan/apply）
├─ policies/
│  ├─ scp/                     # 组织SCP“十条红线”示例
│  │  ├─ deny-root-actions.json
│  │  ├─ deny-unencrypted-s3.json
│  │  ├─ deny-public-acls.json
│  │  ├─ ...
│  ├─ iam/
│  │  ├─ permission-boundary.json
│  │  └─ role-trust-templates/
│  └─ cfn-guard/               # CloudFormation Guard 规则（如需）
├─ modules/
│  ├─ account-baseline/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  ├─ outputs.tf
│  │  └─ README.md
│  ├─ network-core/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  ├─ outputs.tf
│  │  └─ README.md
│  ├─ iam-sso/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  ├─ outputs.tf
│  │  └─ README.md
│  ├─ observability/
│  │  ├─ main.tf variables.tf outputs.tf README.md
│  ├─ cicd-foundation/
│  │  ├─ main.tf variables.tf outputs.tf README.md
│  ├─ ecs-fargate-service/
│  │  ├─ main.tf variables.tf outputs.tf README.md
│  ├─ eks-workload/
│  │  ├─ main.tf variables.tf outputs.tf README.md
│  ├─ rds-aurora-cluster/
│  │  ├─ main.tf variables.tf outputs.tf README.md
│  └─ batch-or-cron/
│     ├─ main.tf variables.tf outputs.tf README.md
├─ stacks/
│  ├─ prod/
│  │  ├─ backend.tf            # 指向 prod 的 state 桶/表
│  │  ├─ main.tf               # 引用模块并连线 outputs→inputs
│  │  ├─ prod.tfvars           # 环境变量文件（敏感值勿入库）
│  │  └─ provider_override.tf  # 指定region、assume_role等
│  ├─ staging/
│  │  ├─ backend.tf main.tf staging.tfvars provider_override.tf
│  └─ dev/
│     ├─ backend.tf main.tf dev.tfvars provider_override.tf
└─ env.example.auto.tfvars     # 通用变量样例（不含敏感值）
```

---

## 顶层文件示例

### `versions.tf`
```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

### `providers.tf`（可选全局；实际建议在 stacks/* 覆盖）
```hcl
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "Default AWS region for root-level provider (overridden per stack)."
  default     = "ap-northeast-1" # Tokyo
}
```

### `backend.example.tf`（复制到各环境并改名为 backend.tf）
```hcl
terraform {
  backend "s3" {
    bucket         = "<ORG_NAME>-tfstate"
    key            = "<STACK_NAME>/terraform.tfstate" # 例: prod/terraform.tfstate
    region         = "ap-northeast-1"
    dynamodb_table = "<ORG_NAME>-tf-lock"
    encrypt        = true
  }
}
```

### `Makefile`
```make
SHELL := /bin/bash
TF   ?= terraform

.PHONY: init fmt validate plan apply destroy
init: ; $(TF) init -upgrade
fmt:  ; $(TF) fmt -recursive
validate: ; $(TF) validate
plan: ; $(TF) plan -var-file=$(ENV).tfvars
apply: ; $(TF) apply -var-file=$(ENV).tfvars -auto-approve
destroy: ; $(TF) destroy -var-file=$(ENV).tfvars -auto-approve
```

---

## 模块：`modules/account-baseline`
> 组织与审计基线（Organizations/Control Tower 可选、CloudTrail/Config/KMS/GuardDuty/SecurityHub/预算告警）。

### `variables.tf`
```hcl
variable "org_enabled" { type = bool, default = true }
variable "organization_units" {
  description = "List of OU names to create or reference."
  type        = list(string)
  default     = ["Sandbox", "Workloads", "Security", "Shared"]
}
variable "audit_account_id" { type = string }
variable "security_account_id" { type = string }
variable "cloudtrail_retention_days" { type = number, default = 365 }
variable "config_recorder" { type = bool, default = true }
variable "kms_multi_region" { type = bool, default = true }
variable "budget_monthly_limit" { type = number, default = 1000 }
variable "tags" { type = map(string), default = {} }
```

### `main.tf`（节选，示意关键资源与依赖）
```hcl
locals {
  common_tags = merge({
    CostCenter = "platform",
    Owner      = "platform-engineering",
  }, var.tags)
}

# 示例：组织（如已由 Control Tower 创建，可改为 data 源引用）
resource "aws_organizations_organization" "this" {
  count = var.org_enabled ? 1 : 0
  feature_set = "ALL"
}

# 组织级 CloudTrail（数据事件/加密/跨账户投递）
resource "aws_cloudtrail" "org" {
  name                          = "org-trail"
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  s3_bucket_name                = aws_s3_bucket.audit_logs.bucket
  kms_key_id                    = aws_kms_key.logs.arn
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource { type = "AWS::S3::Object";   values = ["arn:aws:s3:::"] }
    data_resource { type = "AWS::Lambda::Function"; values = ["arn:aws:lambda"] }
  }
  tags = local.common_tags
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "${replace(lower("<ORG_NAME>"), " ", "-")}-audit-logs"
  force_destroy = false
  tags = local.common_tags
}

resource "aws_kms_key" "logs" {
  description             = "KMS for audit logs"
  enable_key_rotation     = true
  multi_region            = var.kms_multi_region
  deletion_window_in_days = 30
  tags = local.common_tags
}

# GuardDuty / SecurityHub 示例（区域化，必要时用 for_each 遍历区域）
resource "aws_guardduty_detector" "this" { enable = true }
resource "aws_securityhub_account" "this" {}

# 预算与告警（示意：月度总额超阈）
resource "aws_budgets_budget" "monthly" {
  name         = "platform-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}
```

### `outputs.tf`
```hcl
output "audit_bucket_name" { value = aws_s3_bucket.audit_logs.bucket }
output "kms_logs_key_arn"  { value = aws_kms_key.logs.arn }
output "org_trail_arn"     { value = try(aws_cloudtrail.org.arn, null) }
```

---

## 模块：`modules/network-core`
> VPC/子网/路由/NAT/端点/TGW/私有DNS等；输出子网与端点策略供上层引用。

### `variables.tf`
```hcl
variable "vpc_cidr" { type = string }
variable "azs"      { type = list(string) }
variable "public_subnet_cidrs"  { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "create_natgw" { type = bool, default = true }
variable "gateway_endpoints" { type = list(string), default = ["s3", "dynamodb"] }
variable "interface_endpoints" { type = list(string), default = ["logs", "ecr.api", "ecr.dkr"] }
variable "tags" { type = map(string), default = {} }
```

### `main.tf`（节选）
```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, { Name = "core" })
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = var.azs[index(var.public_subnet_cidrs, each.value)]
  tags = merge(var.tags, { Tier = "public" })
}

resource "aws_subnet" "private" {
  for_each = toset(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.azs[index(var.private_subnet_cidrs, each.value)]
  tags = merge(var.tags, { Tier = "private" })
}

# 端点示意：网关端点（S3/DDB）
resource "aws_vpc_endpoint" "gateway" {
  for_each      = toset(var.gateway_endpoints)
  vpc_id        = aws_vpc.this.id
  service_name  = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
}

data "aws_region" "current" {}
```

### `outputs.tf`
```hcl
output "vpc_id"            { value = aws_vpc.this.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public  : s.id] }
output "private_subnet_ids"{ value = [for s in aws_subnet.private : s.id] }
```

---

## 模块：`modules/iam-sso`
> SSO 权限集、跨账号角色、权限边界、常用信任策略模板。

### `variables.tf`
```hcl
variable "permission_boundary_policy_json" { type = string }
variable "sso_permission_sets" {
  description = "List of SSO permission sets (name → policy ARNs)."
  type = list(object({
    name        = string
    managed_policies = list(string)
    session_duration = optional(string, "PT8H")
  }))
  default = []
}
variable "tags" { type = map(string), default = {} }
```

### `main.tf`（节选）
```hcl
# 权限边界示例（供角色/用户复用）
resource "aws_iam_policy" "permission_boundary" {
  name        = "permission-boundary"
  description = "Org-wide permission boundary"
  policy      = var.permission_boundary_policy_json
}

# 如需配置 IAM Identity Center（SSO），可接入 sso-admin 相关资源（需先手工开通）
```

### `outputs.tf`
```hcl
output "permission_boundary_arn" { value = aws_iam_policy.permission_boundary.arn }
```

---

## 模块：`modules/observability`（示例）
```hcl
# main.tf
resource "aws_cloudwatch_log_group" "app" {
  name              = "/platform/app"
  retention_in_days = 30
}

resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "http-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
}
```

---

## 模块：`modules/cicd-foundation`（示例）
```hcl
# main.tf（可替换为与 GitHub Actions 的OIDC对接，而非 CodePipeline）
resource "aws_codepipeline" "iacinfra" {
  name     = "iacinfra"
  role_arn = aws_iam_role.pipeline.arn
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }
}
```

---

## 服务蓝图：`modules/ecs-fargate-service`（节选）
```hcl
variable "service_name" { type = string }
variable "subnet_ids"   { type = list(string) }
variable "desired_count"{ type = number, default = 2 }

# 省略：ECS Cluster、TaskDefinition(含日志/KMS)、Service(ALB/TargetGroup/ASG)
# 输出：service_arn, lb_dns_name, log_group_name 等
```

---

## 环境栈：`stacks/prod/main.tf`（把模块连起来）
```hcl
terraform { required_version = ">= 1.6.0" }

provider "aws" {
  region = var.region
  # 可选：assume_role 坐进 prod 管理账号
}

module "baseline" {
  source                 = "../../modules/account-baseline"
  audit_account_id       = var.audit_account_id
  security_account_id    = var.security_account_id
  budget_monthly_limit   = var.budget_usd
  organization_units     = var.ous
  cloudtrail_retention_days = 365
  tags = var.tags
}

module "network" {
  source               = "../../modules/network-core"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnets
  private_subnet_cidrs = var.private_subnets
  interface_endpoints  = ["logs", "ecr.api", "ecr.dkr"]
  gateway_endpoints    = ["s3", "dynamodb"]
  tags                 = var.tags
}

module "iam" {
  source = "../../modules/iam-sso"
  permission_boundary_policy_json = file("../../policies/iam/permission-boundary.json")
}

# 示例：服务蓝图引用
# module "service_web" {
#   source        = "../../modules/ecs-fargate-service"
#   service_name  = "web"
#   subnet_ids    = module.network.private_subnet_ids
#   desired_count = 2
# }
```

### `stacks/prod/prod.tfvars`（示例变量值）
```hcl
region            = "ap-northeast-1"
audit_account_id  = "123456789012"
security_account_id = "210987654321"
ous               = ["Sandbox", "Workloads", "Security", "Shared"]
vpc_cidr          = "10.10.0.0/16"
azs               = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
public_subnets    = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
private_subnets   = ["10.10.10.0/24", "10.10.11.0/24", "10.10.12.0/24"]
budget_usd        = 2000
tags = { Env = "prod", CostCenter = "platform" }
```

---

## 使用指南（首周就能跑）
1. **创建 S3 桶 + DynamoDB 表** 作为远端 state（按 `backend.example.tf` 修改为 `backend.tf`）。
2. 在 `stacks/prod/` 执行：
   ```bash
   terraform init && terraform fmt -recursive && terraform validate
   terraform plan -var-file=prod.tfvars
   terraform apply -var-file=prod.tfvars
   ```
3. 先上 `account-baseline` 与 `network-core`，观察 CloudTrail/Config/GuardDuty 是否就绪，再逐步启用其他模块。
4. 把 **SCP 规则** 与 **权限边界**逐步收紧（先观察、后强制），避免一次性“锁死”。

---

## 依赖关系（思维导图式）
- **account-baseline**（提供：审计桶/KMS/预算等） → 其他模块共享日志与KMS
- **network-core**（提供：VPC/子网/端点） → 服务蓝图/观测/CI 依赖子网与端点
- **iam-sso**（提供：权限边界/角色） → CI/CD 与各服务的执行角色
- **observability**（可单独部署） → 各服务写日志与指标
- **cicd-foundation**（可单独部署） → 驱动 IaC/应用发布
- **服务蓝图**（依赖：网络+观测+IAM）

---

## 注意事项
- **状态管理**：同一环境的 `backend.tf` 必须唯一；分环境分 `key`。
- **敏感值**：不要入库（改用 SSM Parameter / Secrets Manager）。
- **命名/标签**：强制 `Owner/CostCenter/DataClass/Env` 标签，支撑 FinOps 与溯源。
- **策略即代码**：逐步引入 tfsec/OPA/Conftest 或 CloudFormation Guard（若CDK/CFN混用）。

> 需要 CDK 版本？我可以基于此结构生成 **Construct 版目录骨架**（TypeScript），并附 `cdk-nag` 规则与 `projen` 自动化脚手架。


---

# 模板合集（用于作品集与考试对齐）

## 1) NFR 基线模板（评审清单版）
> 用于：所有新项目立项/评审前先填；与 SAP‑C02 的 WA 六支柱对齐。

**项目/系统：**
**版本/日期：**

### 1. 可用性/可靠性（例：SLA 99.9% / RTO / RPO）
- [ ] 目标 SLA：__ ；**关键路径**：__
- [ ] **RTO**：__；**RPO**：__；灾备级别：(_Pilot-Light_ / _Warm‑Standby_ / _Multi‑Site_)
- [ ] 跨 AZ：__；跨 Region（必要性/数据主权）：__
- [ ] 依赖的外部服务/单点识别与缓解：__

### 2. 安全/合规
- [ ] **默认加密**（KMS Key、密钥分域/轮换）：__
- [ ] 审计集中（CloudTrail/Config/SecurityHub/GuardDuty）：__
- [ ] 身份与访问（最小权限、SSO 权限集、IRSA/角色信任）：__
- [ ] 数据分级/保留/脱敏/越权告警：__

### 3. 性能与容量
- [ ] 峰值 QPS / 并发：__；地区分布：__
- [ ] 缓存策略（热点/多级/TTL）：__；读写隔离：__
- [ ] 弹性方案（AutoScaling/队列/背压）：__

### 4. 可观测性与运维
- [ ] 日志/指标/追踪最小集（结构化日志、RED/USE 指标、Trace）：__
- [ ] SLO/错误预算/告警路由：__
- [ ] 发布策略（蓝绿/金丝雀/自动回滚阈值）：__

### 5. 成本与可持续性
- [ ] 预算阈值/超额告警：__；**单位业务成本口径**：__
- [ ] 节省计划/RI 策略：__；闲置资源回收：__
- [ ] 每千请求/每订单能耗估算（可选）：__

**评审结论（必填）**：准入/限期整改项（列出编号与负责人）。

---

## 2) ADR 模板（含示例）
> 架构决策记录（1 页内），每个关键权衡写一条。

**标题**：__（例如：跨账号接入选 _PrivateLink_ 还是 _VPC Peering_）
**状态**：Proposed / Accepted / Deprecated
**背景**：业务约束（合规/停机窗口/预算/数据主权）：__
**选项**：
- A：__（优点/缺点）
- B：__（优点/缺点）
- C：__（优点/缺点）
**决定**：选择 __，因为 __（与 NFR 映射）
**后果**：
- 积极：__
- 消极与缓解：__（监控/回退/SLA）
**参考**：图/链接/成本测算。

**示例摘要**：
- 标题：对 B2B 只读访问采用 **PrivateLink**；
- 背景：第三方需私网访问、我方不暴露公网、合规要求审计集中；
- 选项：PrivateLink / TGW + Peering / 公网 + WAF；
- 决定：选 **PrivateLink**（最小暴露，精确端点策略）；
- 后果：带宽与端点数量成本↑；以 **Budget + EndpointPolicy** 控制。

---

## 3) 演练与压测报告模板（含指标口径）
**场景**：__（例：电商大促峰值、跨 AZ 故障、数据库主从切换）
**时间/环境**：__（dev/staging/prod；Region/AZ）

### 指标口径
- **SLO**：可用性 _99.9%_；P95 延迟 _≤ 300ms_；错误率 _< 0.1%_
- **可靠性**：RTO：__；RPO：__；MTTR：__
- **成本**：单位业务量成本（每千请求/每订单）= 账单周期总成本 / 业务量

### 操作步骤
1) 基线：无缓存/单区/默认副本；记录指标
2) 变更：启用缓存/加只读副本/多 AZ
3) 故障注入：关一台/断一条链路/降级后端
4) 回滚/恢复

### 结果与图表（贴图或链接）
- P95/吞吐/错误率曲线
- 成本对比（优化前后）
- 事件时间线（告警→响应→恢复）

### 结论与改进
- 达成/未达成项；下一步行动与 Owner/截止日期

**附：k6 压测最小脚本示例**
```js
import http from 'k6/http';
import { sleep } from 'k6';
export const options = { stages: [ { duration: '1m', target: 50 }, { duration: '3m', target: 200 }, { duration: '1m', target: 0 } ] };
export default function () {
  http.get(__ENV.TARGET || 'https://example.com/health');
  sleep(0.5);
}
```

---

## 4) 作品集一页纸（可导出 PDF）
**项目名**：__（电商 / SaaS 多租户 / 流媒体 / IoT）  
**摘要（3 句）**：
- 目标与约束（SLA/RTO/RPO/预算/合规）
- 关键决策（例：多账号着陆区、PrivateLink、Warm‑Standby、蓝绿发布）
- 结果（SLO、MTTR、单位成本改善%）

**架构图**：逻辑 + 部署（放图）

**指标与演练**：贴 2 张图（P95/可用性、成本）+ 一条 DR/发布演练时间线

**链接**：
- ADR/NFR 文档
- Terraform/CDK 仓库（模块/栈）
- 演练报告

---

## 5) 题材：电商最小可运行参数（`stacks/dev/dev.tfvars` 示例）
```hcl
# Region & AZ
region  = "ap-northeast-1"
azs     = ["ap-northeast-1a","ap-northeast-1c","ap-northeast-1d"]

# 组织/审计
audit_account_id    = "111111111111"
security_account_id = "222222222222"
ous                 = ["Sandbox","Workloads","Security","Shared"]

# 网络
vpc_cidr        = "10.20.0.0/16"
public_subnets  = ["10.20.0.0/24","10.20.1.0/24","10.20.2.0/24"]
private_subnets = ["10.20.10.0/24","10.20.11.0/24","10.20.12.0/24"]

# 预算（USD）
budget_usd = 200

# 标签
tags = { Env = "dev", Project = "demo‑ecommerce", CostCenter = "platform" }
```

**电商服务蓝图最小调用（`stacks/dev/main.tf` 片段）**
```hcl
module "baseline" { source = "../../modules/account-baseline"  audit_account_id = var.audit_account_id  security_account_id = var.security_account_id  budget_monthly_limit = var.budget_usd  organization_units = var.ous  tags = var.tags }
module "network"  { source = "../../modules/network-core"      vpc_cidr = var.vpc_cidr  azs = var.azs  public_subnet_cidrs = var.public_subnets  private_subnet_cidrs = var.private_subnets  tags = var.tags }
module "iam"      { source = "../../modules/iam-sso"           permission_boundary_policy_json = file("../../policies/iam/permission-boundary.json") }

module "svc_order" {
  source        = "../../modules/ecs-fargate-service"
  service_name  = "order-api"
  subnet_ids    = module.network.private_subnet_ids
  desired_count = 2
  # 可选：镜像、端口、健康探针、日志保留、SLO 阈值等变量
}
```

> 提示：若先做 **SaaS 多租户**，把 `tags` 中加入 `Tenant`，并演示按租户聚合日志/成本；若做 **流媒体**，在网络模块中加 CloudFront + S3 的输出与最小 OAI/OAC 配置占位。

---

**下一步建议**：
- 先用上面的 `dev.tfvars` 起一个 **dev** 环境做“冒烟”（日志/预算/告警要能看到）；
- 选 **电商 or SaaS 多租户** 其中一个，按照模板补 1 份 NFR + 2 条 ADR + 1 份演练报告；
- 我再根据你的产出，补充“盲点清单 → SAP‑C02 查缺题目”对应关系。

---

# examples/localstack/（本地零成本练手套件）
> 目标：在 **不连接真实 AWS** 的情况下，练习 Terraform 模块/计划/执行、事件驱动（S3→Lambda）与性能压测（k6），并用 **Infracost** 在本地 PR/命令行预估成本。

## 目录结构
```text
examples/localstack/
├─ README.md
├─ docker-compose.yml         # 一键启动 LocalStack
├─ providers.localstack.tf    # 指向本地 4566 端口的 AWS Provider 配置
├─ main.tf                    # 示例：S3 桶、DynamoDB 表、Lambda（模拟）及事件触发
├─ variables.tf               # 示例资源的可调参数
├─ outputs.tf                 # 导出便于测试/脚本使用的字段
├─ lambda/
│  ├─ handler.py              # 简单打印事件的 Lambda 处理器
│  └─ build.sh                # 打包成 zip（供 Terraform 部署）
├─ k6/
│  └─ smoke.js                # 最小压测脚本（走本地模拟的 API 网关 URL 占位）
└─ infracost/
   ├─ infracost.yml           # Infracost 项目配置（指向当前目录）
   └─ README.md               # 如何本地估算成本（离线模式/提示）
```

## README.md（内容）
```md
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
curl http://localhost:4566/\
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
```

## docker-compose.yml
```yaml
version: "3.8"
services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"   # Edge endpoint
    environment:
      - SERVICES=s3,dynamodb,lambda,iam,cloudwatch,logs,apigateway
      - DEBUG=1
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
```

## providers.localstack.tf
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# 指向本地 LocalStack 的 AWS Provider
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  endpoints {
    s3         = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    iam        = "http://localhost:4566"
    logs       = "http://localhost:4566"
    cloudwatch = "http://localhost:4566"
  }
}
```

## variables.tf（示例参数）
```hcl
variable "bucket_name" { type = string, default = "tf-demo-bucket" }
variable "table_name"  { type = string, default = "tf-demo-table" }
```

## main.tf（核心资源：S3 + DynamoDB + Lambda 事件）
```hcl
resource "aws_s3_bucket" "demo" {
  bucket = var.bucket_name
}

resource "aws_dynamodb_table" "demo" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute { name = "id" type = "S" }
}

# IAM 角色（最小，LocalStack 宽松，真实 AWS 需加策略）
resource "aws_iam_role" "lambda_role" {
  name               = "demo-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
  }
}

# 打包 Lambda（依赖 lambda/build.sh 生成的 zip）
resource "aws_lambda_function" "handler" {
  filename         = "lambda/dist/function.zip"
  function_name    = "demo-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = filebase64sha256("lambda/dist/function.zip")
}

# S3 → Lambda 事件触发
resource "aws_s3_bucket_notification" "demo" {
  bucket = aws_s3_bucket.demo.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.handler.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.demo.arn
}
```

## outputs.tf
```hcl
output "bucket_name" { value = aws_s3_bucket.demo.bucket }
output "table_name"  { value = aws_dynamodb_table.demo.name }
output "lambda_name" { value = aws_lambda_function.handler.function_name }
```

## lambda/handler.py
```python
import json

def lambda_handler(event, context):
    print("EVENT:", json.dumps(event))
    return {"status": "ok", "records": len(event.get("Records", []))}
```

## lambda/build.sh
```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p lambda/dist
zip -j lambda/dist/function.zip lambda/handler.py >/dev/null
```

## k6/smoke.js（占位示例）
```js
import http from 'k6/http';
import { sleep } from 'k6';
export const options = { vus: 5, duration: '30s' };
export default function () {
  http.get(__ENV.TARGET || 'http://localhost:4566/health');
  sleep(0.5);
}
```

## infracost/infracost.yml
```yaml
version: 0.1
projects:
  - path: ..
    name: localstack-demo
```

## infracost/README.md（内容）
```md
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
```

---

## 根 Makefile 增补（便捷命令）
```make
localstack-up:   ; docker compose -f examples/localstack/docker-compose.yml up -d
localstack-down: ; docker compose -f examples/localstack/docker-compose.yml down
ls-init:         ; cd examples/localstack && terraform init
ls-plan:         ; cd examples/localstack && terraform plan
ls-apply:        ; cd examples/localstack && ./lambda/build.sh && terraform apply -auto-approve
ls-destroy:      ; cd examples/localstack && terraform destroy -auto-approve
k6:              ; cd examples/localstack && k6 run k6/smoke.js
cost:            ; cd examples/localstack && infracost breakdown --path infracost/infracost.yml
```

> 说明：LocalStack 对 VPC/网络类能力支持有限（可练 S3/DDB/Lambda/队列/日志/部分 API Gateway）。需要练 **VPC/端点/IAM/CloudTrail** 等“真特性”，请切换到你创建的 **沙箱账号** 并配好预算/销毁策略。


---

# examples/aws-sandbox/（上云低成本沙箱，一键起—一键灭）
> 目标：在**真实 AWS 账号**里练习 VPC / 端点（网关型）/ IAM / CloudTrail /（可选）Config，**不产生 NAT 网关/接口端点的月租**；默认月预算 $5，美东/东京均可。适合配合 SAP‑C02 学习。

## 架构取舍（控制成本的关键）
- **无 NAT 网关**（NAT 每个 ~$30/月，直接禁用）。
- 仅用 **网关型 VPC 端点**（S3/DynamoDB），**不创建接口型端点**（接口端点有按小时计费）。
- 练习计算层采用 **Lambda 非 VPC 模式** 或 **ECS Fargate 公网子网**（避免私网出网需求）。
- **CloudTrail 组织/账户级 1 条**，S3 生命周期 7 天；**Config 可选**，若开启仅记录少量资源类型。
- **Budgets** 设置 $5/月，超额邮件/SNS 告警；所有资源强制 `TTL` 标签，配自动清理。

## 目录结构
```text
examples/aws-sandbox/
├─ README.md
├─ backend.tf.example         # 复制到 stacks/dev/backend.tf 使用
├─ providers.tf               # 指定 region/可选 assume_role
├─ variables.tf               # 环境参数（Region/CIDR/子网/标签/预算等）
├─ main.tf                    # 组装：VPC(无NAT)+S3/DDB网关端点+Trail+（可选）Config+Budgets
├─ outputs.tf                 # 输出子网/VPC/日志桶等
├─ lambda_hello/              # 非VPC的最小Lambda（避免接口端点）
│  ├─ handler.py
│  └─ build.sh
├─ cleanup/                   # TTL 自动清理脚本（按标签筛选）
│  └─ nuke_by_ttl.sh
└─ .budget.sample.json        # Budgets 创建参数样例
```

## providers.tf（示例）
```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = var.region
  # 可选：assume_role 到沙箱子账号
  # assume_role { role_arn = var.assume_role_arn }
}
```

## variables.tf（最小参数）
```hcl
variable "region"   { type = string, default = "ap-northeast-1" }
variable "vpc_cidr" { type = string, default = "10.30.0.0/16" }
variable "azs"      { type = list(string), default = ["ap-northeast-1a","ap-northeast-1c"] }
variable "public_subnet_cidrs"  { type = list(string), default = ["10.30.0.0/24","10.30.1.0/24"] }
variable "private_subnet_cidrs" { type = list(string), default = ["10.30.10.0/24","10.30.11.0/24"] }
variable "budget_usd" { type = number, default = 5 }
variable "enable_config" { type = bool, default = false } # 成本敏感，默认关
variable "ttl_hours" { type = number, default = 24 }
variable "tags" { type = map(string), default = { Env = "dev", Project = "aws-sandbox" } }
```

## main.tf（核心资源：VPC(无NAT)+端点+CloudTrail+预算）
```hcl
locals {
  tags = merge(var.tags, { TTL = "${var.ttl_hours}h" })
}

# VPC（无 NAT，仅公/私子网）
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "sandbox-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = local.tags
}

resource "aws_subnet" "public" {
  for_each                 = toset(var.public_subnet_cidrs)
  vpc_id                   = aws_vpc.this.id
  cidr_block               = each.value
  map_public_ip_on_launch  = true
  availability_zone        = var.azs[index(var.public_subnet_cidrs, each.value)]
  tags = merge(local.tags, { Tier = "public" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = local.tags
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each          = toset(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.azs[index(var.private_subnet_cidrs, each.value)]
  tags = merge(local.tags, { Tier = "private" })
}

# VPC 端点：仅网关型（免费）
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.region}.s3"
  route_table_ids   = [aws_route_table.public.id] # 如需给私网路由，也可再建私网路由表
  tags = local.tags
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  route_table_ids   = [aws_route_table.public.id]
  tags = local.tags
}

# CloudTrail（账户级，写入 S3；7 天生命周期）
resource "aws_s3_bucket" "trail" {
  bucket        = "${replace(lower("sandbox-trail-${var.region}"), "_", "-")}-${random_id.suffix.hex}"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    id     = "expire"
    status = "Enabled"
    expiration { days = 7 }
  }
}

resource "aws_cloudtrail" "acc" {
  name                          = "sandbox-trail"
  s3_bucket_name                = aws_s3_bucket.trail.bucket
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  tags                          = local.tags
}

resource "random_id" "suffix" { byte_length = 2 }

# （可选）AWS Config —— 默认关闭，避免费用；开启时仅记录少量资源类型
resource "aws_config_configuration_recorder" "rec" {
  count = var.enable_config ? 1 : 0
  name  = "default"
  role_arn = aws_iam_role.config[0].arn
  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = ["AWS::EC2::VPC","AWS::EC2::Subnet","AWS::S3::Bucket"]
  }
}

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name = "aws-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
}

data "aws_iam_policy_document" "config_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["config.amazonaws.com"] }
  }
}

# Budgets：月度上限 + 通知（示例使用电子邮件，可改 SNS）
resource "aws_budgets_budget" "monthly" {
  name         = "sandbox-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}

# 演示用 Lambda（非 VPC，不需接口端点）
resource "aws_iam_role" "lambda" {
  name               = "sandbox-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement { actions=["sts:AssumeRole"]; principals{ type="Service" identifiers=["lambda.amazonaws.com"] } }
}

resource "aws_lambda_function" "hello" {
  filename         = "${path.module}/lambda_hello/dist/function.zip"
  function_name    = "hello"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = filebase64sha256("${path.module}/lambda_hello/dist/function.zip")
  tags             = local.tags
}

resource "aws_cloudwatch_event_rule" "cron" {
  name                = "hello-cron"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "cron_target" {
  rule      = aws_cloudwatch_event_rule.cron.name
  target_id = "lambda"
  arn       = aws_lambda_function.hello.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron.arn
}
```

## outputs.tf
```hcl
output "vpc_id"            { value = aws_vpc.this.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public  : s.id] }
output "private_subnet_ids"{ value = [for s in aws_subnet.private : s.id] }
output "trail_bucket_name" { value = aws_s3_bucket.trail.bucket }
```

## lambda_hello/handler.py
```python
def lambda_handler(event, context):
    return {"ok": True}
```

## lambda_hello/build.sh
```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname "$0")/dist"
zip -j "$(dirname "$0")/dist/function.zip" "$(dirname "$0")/handler.py" >/dev/null
```

## cleanup/nuke_by_ttl.sh（按 TTL 标签清理资源，占位思路）
```bash
#!/usr/bin/env bash
# 思路：用 AWS CLI 过滤 TTL 过期的资源并逐类删除（S3/Lambda/Budgets/VPC等）
# 为安全起见，默认 dry-run，确认后再执行删除。
```

## backend.tf.example（复制到 stacks/dev/backend.tf）
```hcl
terraform {
  backend "s3" {
    bucket         = "<YOUR_TFSTATE_BUCKET>"
    key            = "dev/aws-sandbox.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "<YOUR_TF_LOCK_TABLE>"
    encrypt        = true
  }
}
```

## README.md（使用步骤）
```md
# AWS 沙箱（低成本）
1) 复制 `backend.tf.example` → `stacks/dev/backend.tf`，指向你的 state 桶/锁表。
2) 构建 Lambda 包：`bash examples/aws-sandbox/lambda_hello/build.sh`
3) 初始化与计划：
   ```bash
   cd examples/aws-sandbox
   terraform init && terraform fmt -recursive && terraform validate
   terraform plan -var="budget_usd=5" -var="ttl_hours=24"
   ```
4) 执行：
   ```bash
   terraform apply -auto-approve
   ```
5) 验证：
   - VPC/子网创建成功，无 NAT 资源；
   - VPC 端点（S3/DDB）生效；
   - CloudTrail 在 S3 写入日志；
   - Lambda 每小时被 EventBridge 触发一次；
6) 清理：
   ```bash
   terraform destroy -auto-approve
   ```

> 建议：开启 **Budgets** 的 SNS/Email 通知；若要用 AWS Config，请将 `enable_config=true`，并保持只记录少量资源类型。
```

## Makefile（根目录附加便捷命令）
```make
aws-sbx-plan:   ; cd examples/aws-sandbox && terraform plan
aws-sbx-apply:  ; cd examples/aws-sandbox && bash lambda_hello/build.sh && terraform apply -auto-approve
aws-sbx-destroy:; cd examples/aws-sandbox && terraform destroy -auto-approve
```

> **成本提示**：本方案不含 NAT 与接口端点，常驻费用≈0；CloudTrail + S3 存储按量计费（7 天生命周期极低）；Lambda/Events 触发在 Free Tier 内基本为 0。确保**用完就 `destroy`**，账单将稳在几美元以内。

