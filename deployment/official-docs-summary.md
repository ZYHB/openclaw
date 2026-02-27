# 官方 Docker 文档整理

本文档整理了 OpenClaw 官方 Docker 部署文档的核心内容，并与我们创建的部署文档进行对比。

## 📋 官方文档结构

官方文档主要包含以下部分：

1. **快速开始**（推荐）
2. **手动部署流程**
3. **高级配置选项**
4. **Agent Sandbox**（沙箱隔离）
5. **故障排查**

## 🚀 快速开始（官方推荐）

### 使用自动部署脚本

```bash
# 从仓库根目录运行
./docker-setup.sh
```

**脚本功能：**
- ✅ 构建 Gateway 镜像
- ✅ 运行 onboarding 向导
- ✅ 打印可选的提供商设置提示
- ✅ 通过 Docker Compose 启动 Gateway
- ✅ 生成 Gateway Token 并写入 `.env`

**完成后：**
- 浏览器打开 `http://127.0.0.1:18789/`
- 使用生成的 Token 登录控制面板
- 配置和数据存储在主机：`~/.openclaw/` 和 `~/.openclaw/workspace`

## 🔧 环境变量选项

### 1. 安装额外的 APT 包

**用途：** 在镜像构建时安装系统包（如 ffmpeg、构建工具）

```bash
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential"
./docker-setup.sh
```

**常用包：**
- `ffmpeg` - 音视频处理
- `build-essential` - 编译工具
- `git curl jq` - 开发工具
- `python3 python3-pip` - Python 支持

### 2. 额外的挂载点

**用途：** 将主机目录挂载到容器中

```bash
export OPENCLAW_EXTRA_MOUNTS="$HOME/.codex:/home/node/.codex:ro,$HOME/github:/home/node/github:rw"
./docker-setup.sh
```

**格式：** `source:target[:options]`（逗号分隔，无空格）

**注意事项：**
- macOS/Windows: 路径必须在 Docker Desktop 中共享
- 修改后需要重新运行 `./docker-setup.sh` 生成 `docker-compose.extra.yml`
- 生成的文件不应手动编辑

### 3. 持久化容器主目录

**用途：** 使用 Docker 卷持久化 `/home/node` 目录

```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
./docker-setup.sh
```

**效果：**
- 创建命名卷 `openclaw_home`
- 挂载到容器的 `/home/node`
- 浏览器下载和工具缓存会持久化
- 容器删除后数据不丢失

**组合使用：**
```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
export OPENCLAW_EXTRA_MOUNTS="$HOME/.codex:/home/node/.codex:ro"
./docker-setup.sh
```

## 🐚 ClawDock Shell 助手

**用途：** 简化日常 Docker 管理的 shell 脚本

### 安装

```bash
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh

# 添加到 shell 配置（zsh）
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc
source ~/.zshrc
```

### 可用命令

| 命令 | 说明 |
|------|------|
| `clawdock-start` | 启动 Gateway |
| `clawdock-stop` | 停止 Gateway |
| `clawdock-dashboard` | 打开控制面板 |
| `clawdock-logs` | 查看日志 |
| `clawdock-restart` | 重启服务 |
| `clawdock-help` | 显示所有命令 |

## 📝 手动部署流程

### 三步手动部署

```bash
# 1. 构建镜像
docker build -t openclaw:local -f Dockerfile .

# 2. 运行 onboarding
docker compose run --rm openclaw-cli onboard

# 3. 启动 Gateway
docker compose up -d openclaw-gateway
```

### 使用额外配置文件

如果启用了 `OPENCLAW_EXTRA_MOUNTS` 或 `OPENCLAW_HOME_VOLUME`：

```bash
docker compose -f docker-compose.yml -f docker-compose.extra.yml up -d
```

## 🔑 Token 认证和设备配对

### 获取 Token

```bash
# 获取控制面板链接和 Token
docker compose run --rm openclaw-cli dashboard --no-open
```

### 设备配对

如果看到 "unauthorized" 或 "disconnected (1008): pairing required"：

```bash
# 1. 获取新的控制面板链接
docker compose run --rm openclaw-cli dashboard --no-open

# 2. 列出待配对设备
docker compose run --rm openclaw-cli devices list

# 3. 批准设备
docker compose run --rm openclaw-cli devices approve <requestId>
```

## 🐳 高级配置选项

### Power User / 功能完整的容器

默认 Docker 镜像是**安全优先**的，以非 root `node` 用户运行，这意味着：
- ❌ 运行时无法安装系统包
- ❌ 默认无 Homebrew
- ❌ 无预装的 Chromium/Playwright 浏览器

### 方案 1：持久化 /home/node

让浏览器下载和工具缓存持久化：

```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
./docker-setup.sh
```

### 方案 2：烘焙系统依赖到镜像

在构建时安装系统包：

```bash
export OPENCLAW_DOCKER_APT_PACKAGES="git curl jq"
./docker-setup.sh
```

### 方案 3：安装 Playwright 浏览器

不使用 `npx`（避免 npm 冲突）：

```bash
docker compose run --rm openclaw-cli \
  node /app/node_modules/playwright-core/cli.js install chromium
```

如果需要 Playwright 安装系统依赖，使用 `OPENCLAW_DOCKER_APT_PACKAGES` 重建镜像。

### 方案 4：持久化 Playwright 浏览器下载

**步骤 1：** 在 `docker-compose.yml` 中设置环境变量：
```yaml
environment:
  PLAYWRIGHT_BROWSERS_PATH: /home/node/.cache/ms-playwright
```

**步骤 2：** 确保 `/home/node` 持久化：
```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
# 或
export OPENCLAW_EXTRA_MOUNTS="$HOME/.cache/ms-playwright:/home/node/.cache/ms-playwright"
```

## ⚠️ 权限问题

### 问题描述

镜像以 `node` 用户（UID 1000）运行，如果主机挂载目录权限不匹配会出现 EACCES 错误。

### 解决方案

```bash
# 修复主机目录权限
sudo chown -R 1000:1000 ~/.openclaw

# 或修复自定义路径
sudo chown -R 1000:1000 /path/to/openclaw-config /path/to/openclaw-workspace
```

## 🏥 健康检查

```bash
# 检查容器健康状态
docker compose exec openclaw-gateway \
  node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"
```

## 🧪 E2E 测试

```bash
# Docker onboard 测试
scripts/e2e/onboard-docker.sh

# QR 导入测试
pnpm test:docker:qr
```

## 📦 Agent Sandbox（重要！）

这是 OpenClaw 的一个**核心安全功能**，用于在隔离的 Docker 容器中运行 Agent 工具。

### 工作原理

当启用 `agents.defaults.sandbox` 时：
- Gateway 运行在主机上
- **非 main 会话**的工具在隔离的 Docker 容器中执行
- 每个代理或会话有独立的容器和工作空间

### 默认行为

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 镜像 | `openclaw-sandbox:bookworm-slim` | 沙箱基础镜像 |
| 容器范围 | `agent` | 每个代理一个容器 |
| 工作空间访问 | `none` | 使用 `~/.openclaw/sandboxes` |
| 自动清理 | 空闲>24h 或 年龄>7天 | 自动删除容器 |
| 网络 | `none` | 无网络访问（增强安全） |

### 启用 Sandbox

**构建沙箱镜像：**
```bash
scripts/sandbox-setup.sh
```

**配置示例：**
```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",      // off | non-main | all
        "scope": "agent",         // session | agent | shared
        "workspaceAccess": "none", // none | ro | rw
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim",
          "workdir": "/workspace",
          "readOnlyRoot": true,
          "tmpfs": ["/tmp", "/var/tmp", "/run"],
          "network": "none",
          "user": "1000:1000",
          "memory": "1g",
          "cpus": 1
        }
      }
    }
  }
}
```

### Sandbox 模式对比

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| `off` | 禁用沙箱 | 完全信任的本地环境 |
| `non-main` | 仅非 main 会话隔离 | **推荐**：保护个人会话 |
| `all` | 所有会话隔离 | 高安全性要求 |

### 工作空间访问

| 模式 | 说明 | 风险 |
|------|------|------|
| `none` | 使用独立沙箱工作空间 | 最安全 |
| `ro` | 只读挂载代理工作空间 | 中等 |
| `rw` | 读写挂载代理工作空间 | 较高 |

### 默认允许/拒绝的工具

**允许：** `exec`, `process`, `read`, `write`, `edit`, `sessions_*`

**拒绝：** `browser`, `canvas`, `nodes`, `cron`, `discord`, `gateway`

### 构建 Sandbox 镜像

```bash
# 默认沙箱镜像
scripts/sandbox-setup.sh

# 带常用工具的镜像（Node, Go, Rust）
scripts/sandbox-common-setup.sh

# 带浏览器的镜像
scripts/sandbox-browser-setup.sh
```

## 🆚 官方文档 vs 我们的部署文档

### 我们的优势

| 方面 | 官方文档 | 我们的文档 |
|------|----------|-----------|
| 目标用户 | 通用开发者 | **物理机部署者** |
| 系统设置 | 简略 | **详细**（Ubuntu/Debian/CentOS/NAS） |
| 问题排查 | 基本 | **全面**（14+ 问题场景） |
| 配置说明 | 分散 | **集中**（完整示例） |
| 环境准备 | 简单 | **全面检查脚本** |
| 安全配置 | 基础 | **深入**（防火墙/fail2ban） |

### 官方文档的优势

| 方面 | 官方文档 | 我们的文档 |
|------|----------|-----------|
| **Agent Sandbox** | ✅ 详细 | ❌ 缺失 |
| **ClawDock 助手** | ✅ 包含 | ❌ 缺失 |
| **最新功能** | ✅ 同步更新 | ⚠️ 可能过时 |
| **版本兼容性** | ✅ 保证 | ⚠️ 需手动验证 |

## 🔍 建议补充到我们的文档

### 1. 添加 Agent Sandbox 专区

在 `deployment/` 文件夹创建 `sandbox.md`：

```markdown
# Agent Sandbox 配置指南

- 什么是 Sandbox
- 为什么需要 Sandbox
- 如何构建沙箱镜像
- 配置示例
- 安全最佳实践
```

**✅ 已完成：** 已创建 `deployment/sandbox.md`，包含完整的 Agent Sandbox 配置指南。

### 2. 添加 ClawDock 使用说明

在 `deployment-guide.md` 中添加：

```bash
# ClawDock 安装和使用
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc
```

**✅ 已完成：** 已在 `deployment-guide.md` 的"ClawDock Shell 助手"章节添加完整的安装和使用说明。

**✅ 2026-02-27 进一步完善：**
- 在"快速部署"章节添加"下一步：安装 ClawDock"推荐流程
- 添加 deploy.sh 与 ClawDock 的工具对比表格
- 添加典型工作流示例
- 新增"部署工具速查表"章节，包含 12+ 常用场景的命令对照

### 3. 更新环境变量文档

在 `configuration.md` 中补充：

```bash
# 官方推荐的环境变量
OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg"
OPENCLAW_EXTRA_MOUNTS="$HOME/docs:/home/node/docs:rw"
OPENCLAW_HOME_VOLUME="openclaw_home"
```

**✅ 已完成：** 已在 `configuration.md` 的"官方推荐环境变量说明"章节添加详细说明和示例。

## 📚 相关链接

- [官方 Docker 文档](https://docs.openclaw.ai/install/docker)
- [Sandboxing 文档](https://docs.openclaw.ai/gateway/sandboxing)
- [ClawDock README](https://github.com/openclaw/openclaw/blob/main/scripts/shell-helpers/README.md)
- [Docker 官方文档](https://docs.docker.com)

---

**更新日期：** 2026-02-27
**官方文档版本：** 基于 main 分支
