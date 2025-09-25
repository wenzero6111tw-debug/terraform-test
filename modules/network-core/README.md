# network-core 模块

创建平台级 VPC、子网、路由与基础端点：

- 单 VPC，启用 DNS 支持。
- 多 AZ 公有 / 私有子网与路由表。
- 可选 NAT（示例代码未实现，请按需扩展）。
- S3、DynamoDB 等网关端点。

接口端点和 Transit Gateway 等高级特性可在此模块基础上继续扩展。
