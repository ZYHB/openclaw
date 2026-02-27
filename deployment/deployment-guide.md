# OpenClaw Docker 部署指南

本文档提供在物理机上使用 Docker 部署 OpenClaw 的详细步骤。

## 目录

- [快速部署](#快速部署)
- [手动部署](#手动部署)
- [部署后配置](#部署后配置)
- [更新和升级](#更新和升级)
- [卸载](#卸载)
- [部署工具速查表](#部署工具速查表)

## 快速部署

使用项目提供的自动化脚本可以快速完成部署。

### 方式 1：使用便捷部署脚本（推荐）⭐

项目根目录提供了 `deploy.sh` 脚本，预配置了推荐的系统包，只需运行一次：

```bash
# 运行部署脚本
./deploy.sh
```

该脚本会：
1. ✅ 自动检查 Docker 环境
2. ✅ 使用预配置的系统包（ffmpeg, git, curl, jq）
3. ✅ 执行官方 docker-setup.sh 脚本
4. ✅ 显示部署进度和后续步骤

**自定义配置：**

编辑 `deploy.sh` 文件，修改配置区域：

```bash
# 安装的系统包
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg git curl jq"

# 额外的挂载点（取消注释并修改）
# export OPENCLAW_EXTRA_MOUNTS="$HOME/Documents:/home/node/documents:rw"

# 持久化卷（取消注释以启用）
# export OPENCLAW_HOME_VOLUME="openclaw_home"
```

**其他选项：**

```bash
# 强制重新构建（无缓存）
./deploy.sh --no-cache

# 传递参数给 docker-setup.sh
./deploy.sh --help
```

### 方式 2：手动使用官方脚本

### 下一步：安装 ClawDock（推荐）

部署完成后，建议安装 ClawDock Shell 助手简化日常管理：

```bash
# 安装 ClawDock
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh

# 添加到 shell 配置
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc  # zsh 用户
source ~/.zshrc

# 或使用 bash
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.bashrc  # bash 用户
source ~/.bashrc
```

常用命令：
- `clawdock-start` - 启动服务
- `clawdock-stop` - 停止服务
- `clawdock-logs` - 查看日志
- `clawdock-dashboard` - 打开控制面板
- `clawdock-restart` - 重启服务

详细说明参见：[ClawDock 使用指南](./clawdock.md)

### 1. 克隆代码库

```bash
# 如果已经克隆，切换到 my-deploy 分支
cd /path/to/openclaw
git checkout my-deploy
git pull origin my-deploy

# 或者从您的 fork 克隆
git clone -b my-deploy https://github.com/YOUR_USERNAME/openclaw.git
cd openclaw
```

### 2. 运行部署脚本

```bash
# 运行自动部署脚本
./docker-setup.sh
```

该脚本会自动执行以下操作：

1. 构建 Docker 镜像
2. 运行 onboarding 向导
3. 生成配置文件
4. 启动 Gateway 容器
5. 生成访问 Token

### 2.1 使用环境变量自定义构建

官方支持通过环境变量自定义镜像构建：

```bash
# 安装额外的 APT 包（如 ffmpeg、构建工具）
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential git jq"

# 添加额外的挂载点（格式：source:target[:options]，逗号分隔）
export OPENCLAW_EXTRA_MOUNTS="$HOME/Documents:/home/node/documents:rw,$HOME/.codex:/home/node/.codex:ro"

# 持久化容器主目录（使用 Docker 卷）
export OPENCLAW_HOME_VOLUME="openclaw_home"

# 然后运行部署脚本
./docker-setup.sh
```

**注意事项：**
- macOS/Windows: 路径必须在 Docker Desktop 中共享
- 修改环境变量后需要重新运行 `./docker-setup.sh`
- 生成的 `docker-compose.extra.yml` 不应手动编辑

### 3. 访问控制界面

部署完成后，脚本会输出访问 URL，通常是：

```
http://your-server-ip:18789/
```

在浏览器中打开该地址，使用生成的 Token 进行身份验证。

### 4. 配置模型提供商

在控制界面中配置您的 AI 模型提供商：

- **OpenAI**：需要 API Key
- **Anthropic**：需要 API Key
- **其他提供商**：根据提示配置

## 手动部署

如果您需要更多控制，可以手动执行每个步骤。

### 步骤 1：准备环境变量

创建 `.env` 文件：

```bash
# 生成随机 Token
GATEWAY_TOKEN=$(openssl rand -hex 32)

# 创建 .env 文件
cat > .env <<EOF
OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN
CLAUDE_AI_SESSION_KEY=$(openssl rand -hex 16)
CLAUDE_WEB_SESSION_KEY=$(openssl rand -hex 16)
CLAUDE_WEB_COOKIE=$(openssl rand -hex 16)

OPENCLAW_CONFIG_DIR=$HOME/.openclaw
OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan
EOF

# 记录 Token（妥善保管！）
echo "Gateway Token: $GATEWAY_TOKEN"
```

### 步骤 2：构建 Docker 镜像

```bash
# 基础镜像构建（约 5-10 分钟）
docker build -t openclaw:local -f Dockerfile .

# 验证镜像
docker images | grep openclaw
```

**高级选项：**

```bash
# 安装额外的系统包（如 ffmpeg）
docker build \
  --build-arg OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg" \
  -t openclaw:local \
  -f Dockerfile .

# 预装 Chromium 浏览器（增加约 300MB）
docker build \
  --build-arg OPENCLAW_INSTALL_BROWSER=1 \
  -t openclaw:local \
  -f Dockerfile .
```

### 步骤 3：准备数据目录

```bash
# 创建配置目录
mkdir -p ~/.openclaw/workspace

# 设置正确的权限（Docker 容器以 UID 1000 运行）
sudo chown -R 1000:1000 ~/.openclaw

# 验证权限
ls -la ~/.openclaw
```

### 步骤 4：运行 Onboarding 向导

```bash
# 使用临时容器运行 onboarding
docker compose run --rm openclaw-cli onboard
```

按照向导提示完成：

1. 选择语言
2. 配置 AI 模型提供商
3. 选择要启用的消息通道
4. 配置安全选项

### 步骤 5：启动 Gateway 服务

```bash
# 启动 gateway 容器（后台运行）
docker compose up -d openclaw-gateway

# 查看日志
docker compose logs -f openclaw-gateway

# 检查容器状态
docker compose ps
```

### 步骤 6：验证部署

```bash
# 检查容器状态
docker compose ps

# 检查健康状态
docker compose exec openclaw-gateway \
  node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"

# 获取控制面板 URL
docker compose run --rm openclaw-cli dashboard --no-open
```

## 部署后配置

### 配置消息通道

#### WhatsApp

```bash
# 运行 QR 码登录
docker compose run --rm openclaw-cli channels login

# 在手机上打开 WhatsApp → 设置 → 关联设备
# 扫描终端显示的 QR 码
```

#### Telegram

```bash
# 从 @BotFather 获取 bot token
docker compose run --rm openclaw-cli \
  channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

#### Discord

```bash
# 从 Discord Developer Portal 获取 bot token
docker compose run --rm openclaw-cli \
  channels add --channel discord --token "YOUR_BOT_TOKEN"
```

### 配置 Nginx 反向代理（可选）

如果需要通过域名或 HTTPS 访问：

```nginx
# /etc/nginx/sites-available/openclaw
upstream openclaw_gateway {
    server 127.0.0.1:18789;
}

server {
    listen 80;
    server_name openclaw.yourdomain.com;

    location / {
        proxy_pass http://openclaw_gateway;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 配置 SSL 证书（推荐）

使用 Let's Encrypt 免费证书：

```bash
# 安装 certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d openclaw.yourdomain.com

# 自动续期
sudo systemctl enable certbot.timer
```

## 更新和升级

### 更新代码

```bash
# 拉取最新代码
git fetch origin
git rebase origin/my-deploy

# 重新构建镜像
docker compose build

# 重启服务
docker compose up -d openclaw-gateway
```

### 更新配置

```bash
# 编辑配置文件
nano ~/.openclaw/config.json

# 重启 gateway 使配置生效
docker compose restart openclaw-gateway
```

### 查看日志

```bash
# 实时日志
docker compose logs -f openclaw-gateway

# 最近 100 行
docker compose logs --tail=100 openclaw-gateway

# 持久化日志到文件
docker compose logs -f openclaw-gateway >> ~/.openclaw/logs/gateway.log 2>&1 &
```

## 卸载

### 停止并删除容器

```bash
# 停止服务
docker compose down

# 删除卷（警告：会删除所有数据！）
docker compose down -v

# 删除镜像
docker rmi openclaw:local
```

### 清理数据

```bash
# 备份配置（可选）
cp -r ~/.openclaw ~/.openclaw.backup

# 删除配置和数据
rm -rf ~/.openclaw

# 删除 .env 文件
rm -f .env
rm -f docker-compose.extra.yml
```

### 完全卸载 Docker（可选）

```bash
# 卸载 Docker Engine
sudo apt-get purge docker-ce docker-ce-cli containerd.io

# 删除所有 Docker 数据
sudo rm -rf /var/lib/docker

# 删除 Docker 组
sudo groupdel docker
```

## 部署模式

### 开发模式

用于开发和测试：

```bash
# 使用绑定挂载实时更新代码
export OPENCLAW_DEV_MODE=1
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

### 生产模式

用于生产环境：

```bash
# 使用持久化卷和资源限制
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 高级配置

### Agent Sandbox（安全隔离）

OpenClaw 提供了 Agent Sandbox 功能，可以在隔离的 Docker 容器中运行 Agent 工具，提高系统安全性。

**快速启用：**

```bash
# 1. 构建沙箱镜像
./scripts/sandbox-setup.sh

# 2. 编辑配置启用 Sandbox
# nano ~/.openclaw/config.json
# 添加:
# {
#   "agents": {
#     "defaults": {
#       "sandbox": {
#         "mode": "non-main"
#       }
#     }
#   }
# }

# 3. 重启 Gateway
docker compose restart openclaw-gateway
```

**详细配置指南：** 参见 [sandbox.md](./sandbox.md)

### 资源限制

编辑 `docker-compose.yml` 添加资源限制：

```yaml
services:
  openclaw-gateway:
    # ... 其他配置 ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

### 自动重启

配置容器的重启策略：

```yaml
services:
  openclaw-gateway:
    restart: unless-stopped
    # or: always, on-failure:5
```

### 日志轮转

配置容器日志大小限制：

```yaml
services:
  openclaw-gateway:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## ClawDock Shell 助手（推荐）

ClawDock 是官方提供的 Shell 脚本集合，用于简化日常的 Docker 管理操作。

**核心价值**：将冗长的 Docker Compose 命令简化为简短的别名

```bash
# ❌ 之前：需要输入完整的 docker compose 命令
docker compose up -d openclaw-gateway

# ✅ 现在：只需简短的别名
clawdock-start
```

### 快速安装

```bash
# 下载并安装 ClawDock
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh

# 添加到 shell 配置
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc  # zsh 用户
source ~/.zshrc
```

### 工具对比：deploy.sh vs ClawDock

| 特性 | deploy.sh | ClawDock |
|------|-----------|----------|
| **主要用途** | 首次部署和重建镜像 | 日常运维管理 |
| **使用时机** | 部署和更新时 | 部署后的日常操作 |
| **环境变量** | ✅ 预配置推荐值 | ❌ 不处理 |
| **命令简化** | ❌ 仅一次性执行 | ✅ 20+ 条别名 |
| **典型场景** | 初次安装、重新构建 | 查看日志、启停服务 |

**两者是互补关系，推荐配合使用！**

### 完整文档

📖 **[ClawDock 使用指南](./clawdock.md)** - 包含 20+ 命令的详细说明、使用示例和故障排查

**快速参考：**

| 常用命令 | 功能 |
|---------|------|
| `clawdock-start` | 启动服务 |
| `clawdock-stop` | 停止服务 |
| `clawdock-logs` | 查看日志 |
| `clawdock-dashboard` | 打开控制面板 |
| `clawdock-restart` | 重启服务 |
| `clawdock-help` | 显示所有命令 |

## 监控和维护

### 容器监控

```bash
# 查看容器资源使用
docker stats openclaw-gateway

# 查看容器详情
docker inspect openclaw-gateway
```

### 定期备份

创建备份脚本：

```bash
#!/bin/bash
# backup.sh - OpenClaw 数据备份脚本

BACKUP_DIR="/backup/openclaw"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# 备份配置
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C ~/.openclaw .

# 备份 Docker 卷
docker run --rm \
  -v openclaw_home:/data \
  -v "$BACKUP_DIR:/backup" \
  alpine tar -czf "/backup/volume_$DATE.tar.gz" -C /data .

# 清理 30 天前的备份
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

echo "备份完成: $BACKUP_DIR/config_$DATE.tar.gz"
```

添加到 crontab：

```bash
# 每天凌晨 2 点备份
0 2 * * * /path/to/backup.sh >> /var/log/openclaw-backup.log 2>&1
```

## 下一步

部署完成后：

1. 阅读 [troubleshooting.md](./troubleshooting.md) 了解常见问题
2. 参考 [configuration.md](./configuration.md) 进行高级配置
3. 配置消息通道和 AI 模型提供商

## 部署工具速查表

### 工具选择指南

| 你想做... | 使用工具 | 命令 |
|----------|---------|------|
| **首次部署 OpenClaw** | deploy.sh | `./deploy.sh` |
| **重新构建镜像** | deploy.sh | `./deploy.sh --no-cache` |
| **修改环境变量后重建** | deploy.sh | 编辑 `deploy.sh` 后运行 |
| **启动服务** | ClawDock | `clawdock-start` |
| **停止服务** | ClawDock | `clawdock-stop` |
| **重启服务** | ClawDock | `clawdock-restart` |
| **查看日志** | ClawDock | `clawdock-logs` |
| **打开控制面板** | ClawDock | `clawdock-dashboard` |
| **检查容器状态** | ClawDock | `clawdock-ps` |
| **进入容器 Shell** | ClawDock | `clawdock-shell` |
| **健康检查** | ClawDock | `clawdock-health` |
| **获取访问 Token** | ClawDock | `clawdock-token` |

### 常用命令对照表

| Docker Compose 原始命令 | ClawDock 简化命令 |
|------------------------|------------------|
| `docker compose up -d openclaw-gateway` | `clawdock-start` |
| `docker compose down` | `clawdock-stop` |
| `docker compose restart openclaw-gateway` | `clawdock-restart` |
| `docker compose logs -f openclaw-gateway` | `clawdock-logs` |
| `docker compose ps` | `clawdock-ps` |
| `docker compose run --rm openclaw-cli dashboard` | `clawdock-dashboard` |
| `docker compose exec openclaw-gateway bash` | `clawdock-shell` |

### 安装顺序

```bash
# 步骤 1：首次部署（必须）
./deploy.sh

# 步骤 2：安装 ClawDock（推荐）
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc
source ~/.zshrc
```

## 获取帮助

如果遇到问题：

- 查看日志：`docker compose logs -f openclaw-gateway`
- 运行诊断：`docker compose run --rm openclaw-cli doctor`
- 提交 Issue：https://github.com/openclaw/openclaw/issues
- 加入 Discord：https://discord.gg/clawd
