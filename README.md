# AWS 平台 Terraform 基线

本仓库按照《Terraform 平台基线目录骨架（AWS）》文档提供的结构搭建，用于演示和初始化 AWS 平台级基础设施代码。

> **提示**：仓库仅包含示例配置，请根据实际组织策略、账号和命名规范进行调整。

## 仓库结构

- 顶层定义 Terraform 全局版本与 provider 约束，并提供后端配置模板。
- `policies/` 存放组织级 SCP、IAM 权限边界等策略文档。
- `modules/` 目录存放复用模块：账号基线、网络基座、IAM/SSO、可观测性、CI/CD、服务蓝图等。
- `stacks/` 目录按环境拆分（`dev`/`staging`/`prod`），组合模块并提供差异化变量。

## 快速开始

1. 复制 `backend.example.tf` 到目标环境目录（如 `stacks/dev/backend.tf`），并填入远端状态存储信息。
2. 在对应环境目录编写或更新 `*.tfvars` 文件，提供所需变量值。
3. 运行 `make init`、`make fmt`、`make validate`、`make plan` 等命令准备与校验基础设施。
4. 根据输出结果执行 `make apply` 部署，或 `make destroy` 清理资源。

更多细节请参考各模块目录下的 `README.md` 文件。
