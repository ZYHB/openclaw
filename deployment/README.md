# OpenClaw Docker 部署文档

本文件夹包含在物理机上使用 Docker 部署 OpenClaw 的完整文档和问题记录。

## 文档结构

| 文档 | 说明 |
|------|------|
| [prerequisites.md](./prerequisites.md) | 部署前置要求和环境准备 |
| [deployment-guide.md](./deployment-guide.md) | 详细的部署步骤指南 |
| [clawdock.md](./clawdock.md) | ClawDock Shell 助手完整使用指南 |
| [feishu-setup.md](./feishu-setup.md) | 飞书（Feishu/Lark）消息通道配置指南 |
| [feishu-pairing-issue.md](./feishu-pairing-issue.md) | 飞书配对问题排查记录 |
| [troubleshooting.md](./troubleshooting.md) | 常见问题和解决方案 |
| [configuration.md](./configuration.md) | 配置文件参考和说明 |
| [environment-setup.md](./environment-setup.md) | 物理机环境设置说明 |
| [sandbox.md](./sandbox.md) | Agent Sandbox 安全配置指南 |
| [official-docs-summary.md](./official-docs-summary.md) | 官方文档整理和对比 |

## 快速开始

如果您已经熟悉 Docker 和 OpenClaw，可以直接参考：

1. **快速部署**：参见 [deployment-guide.md](./deployment-guide.md#快速部署)
2. **遇到问题**：查看 [troubleshooting.md](./troubleshooting.md)
3. **配置调整**：参考 [configuration.md](./configuration.md)

## 部署环境

- **操作系统**：Linux (Ubuntu 22.04+ 推荐)
- **容器运行时**：Docker 24.0+ / Docker Compose v2
- **硬件要求**：
  - CPU：2 核心以上
  - 内存：4GB 以上（推荐 8GB）
  - 磁盘：20GB 以上可用空间

## 相关资源

- OpenClaw 官方文档：https://docs.openclaw.ai
- Docker 官方文档：https://docs.docker.com
- GitHub 仓库：https://github.com/openclaw/openclaw

## 更新日志

| 日期 | 更新内容 |
|------|---------|
| 2026-02-27 | 补充 ClawDock 和官方环境变量说明，创建 Agent Sandbox 专题文档 |
| 2026-02-27 | 添加 deploy.sh 与 ClawDock 工具对比说明，新增部署工具速查表 |
| 2026-02-27 | 创建 clawdock.md 专题文档，包含 20+ 命令的完整说明和使用示例 |
| 2026-02-27 | 创建 feishu-setup.md 飞书配置指南，包含完整的 Docker 环境设置步骤 |
| 2026-02-27 | 创建 feishu-pairing-issue.md 飞书配对问题排查记录，包含完整的诊断和解决过程 |
| 2025-02-27 | 创建部署文档文件夹 |

---

**注意**：本部署文档基于 `my-deploy` 分支，针对物理机 Docker 部署场景定制。
