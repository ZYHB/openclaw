# 前置要求和环境准备

本文档描述在物理机上部署 OpenClaw Docker 容器所需的系统要求和环境准备工作。

## 系统要求

### 硬件要求

| 资源 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 2 核心 | 4 核心以上 |
| 内存 | 4GB | 8GB 以上 |
| 磁盘空间 | 20GB | 50GB 以上（SSD 推荐） |
| 网络 | 稳定的网络连接 | 宽带连接 |

### 操作系统

**支持的系统：**
- Ubuntu 20.04 LTS / 22.04 LTS / 24.04 LTS
- Debian 11+ / 12+
- CentOS Stream 8+ / Rocky Linux 8+
- 其他主流 Linux 发行版

**系统要求：**
- 64 位 x86_64 架构（ARM64 需要额外配置）
- 内核版本 4.0 以上
- 支持 Docker Engine

## 软件依赖

### Docker 安装

#### 推荐版本
- Docker Engine: **24.0+**
- Docker Compose: **v2** (作为 Docker 插件)

#### 验证 Docker 安装

```bash
# 检查 Docker 版本
docker --version
# 应该输出: Docker version 24.x.x 或更高

# 检查 Docker Compose 版本
docker compose version
# 应该输出: Docker Compose version v2.x.x

# 验证 Docker 是否正常运行
docker ps
# 应该能列出容器（即使为空）
```

#### Docker 安装脚本（Ubuntu/Debian）

如果尚未安装 Docker，可以使用官方脚本：

```bash
# 下载并运行 Docker 安装脚本
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 将当前用户添加到 docker 组（免 sudo 运行）
sudo usermod -aG docker $USER

# 重新登录或运行以下命令使组权限生效
newgrp docker

# 验证安装
docker --version
docker compose version
```

### 端口要求

OpenClaw 默认使用以下端口，请确保防火墙允许这些端口：

| 端口 | 用途 | 说明 |
|------|------|------|
| 18789 | Gateway Websocket | 主要的 WebSocket 连接端口 |
| 18790 | Bridge Bridge | 桥接服务端口 |

**防火墙配置示例（ufw）：**

```bash
# 允许 OpenClaw 端口
sudo ufw allow 18789/tcp
sudo ufw allow 18790/tcp

# 如果需要从外网访问（谨慎！）
sudo ufw allow from <your-ip> to any port 18789
```

## 网络要求

### 外网访问

OpenClaw 部署过程中需要访问以下服务：

- **npm 注册表**：下载依赖包
- **模型提供商 API**：OpenAI / Anthropic / 其他
- **GitHub**：拉取代码和更新（如果从源码构建）
- **消息通道服务**：WhatsApp / Telegram / Discord 等

**如果服务器在中国大陆**，可能需要配置代理或镜像源：

```bash
# npm 配置淘宝镜像
npm config set registry https://registry.npmmirror.com

# Docker 配置国内镜像（编辑 /etc/docker/daemon.json）
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live"
  ]
}
EOF

# 重启 Docker 服务
sudo systemctl restart docker
```

## 权限要求

### 文件系统权限

Docker 容器默认以 `node` 用户（UID 1000）运行，需要确保：

1. **配置目录权限**：`~/.openclaw` 目录的所有者为 UID 1000
2. **工作空间权限**：`~/.openclaw/workspace` 可写
3. **挂载卷权限**：任何通过 Docker 挂载的目录都有正确的权限

**权限修复命令：**

```bash
# 修复配置目录权限
sudo chown -R 1000:1000 ~/.openclaw

# 如果需要为其他用户准备目录
sudo mkdir -p /opt/openclaw
sudo chown -R 1000:1000 /opt/openclaw
```

### Docker 权限

确保当前用户可以免 sudo 运行 Docker 命令：

```bash
# 检查用户组
groups

# 如果没有 docker 组，添加用户到组
sudo usermod -aG docker $USER
newgrp docker

# 测试
docker ps
```

## 存储准备

### 数据持久化目录

OpenClaw 需要持久化以下数据：

| 路径 | 说明 | 大小预估 |
|------|------|---------|
| `~/.openclaw/` | 配置和会话数据 | 100MB - 1GB |
| `~/.openclaw/workspace/` | 工作空间文件 | 根据使用情况 |
| `~/.openclaw/sessions/` | 会话日志 | 根据使用情况 |
| Docker volumes | 容器数据 | 1GB+ |

**推荐配置：**

1. **使用专用磁盘或分区**（可选）
2. **配置定期清理**：防止日志和会话数据无限增长
3. **备份策略**：定期备份 `~/.openclaw/` 目录

### 日志管理

```bash
# 创建日志目录
mkdir -p ~/.openclaw/logs

# 配置 logrotate（创建 /etc/logrotate.d/openclaw）
cat <<EOF | sudo tee /etc/logrotate.d/openclaw
/home/*/.openclaw/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

## 环境变量准备

创建环境变量文件 `.env` 在项目根目录：

```bash
# 生成随机 Token
openssl rand -hex 32

# 创建 .env 文件
cat > .env <<EOF
# Gateway Token (必需)
OPENCLAW_GATEWAY_TOKEN=your-random-token-here

# 端口配置
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790

# 数据目录
OPENCLAW_CONFIG_DIR=$HOME/.openclaw
OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace

# Gateway 绑定地址 (lan | loopback)
OPENCLAW_GATEWAY_BIND=lan

# 会话密钥（可选）
CLAUDE_AI_SESSION_KEY=ai-session-key
CLAUDE_WEB_SESSION_KEY=web-session-key
CLAUDE_WEB_COOKIE=web-cookie-secret
EOF
```

## 可选组件

### 数据库（可选）

如果需要使用高级功能（如向量存储），可以安装：

- **PostgreSQL**：用于结构化数据存储
- **Redis**：用于缓存和队列
- **Qdrant / LanceDB**：用于向量存储

### 代理服务器（可选）

如果服务器需要通过代理访问外网：

```bash
# 配置环境变量
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
export NO_PROXY=localhost,127.0.0.1

# 配置 Docker 代理
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

# 重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 健康检查

在开始部署前，运行以下命令检查环境：

```bash
#!/bin/bash
# 环境检查脚本

echo "=== OpenClaw 部署环境检查 ==="

# 1. Docker 检查
echo -n "检查 Docker... "
if command -v docker &> /dev/null; then
    docker --version
else
    echo "未安装"
    exit 1
fi

# 2. Docker Compose 检查
echo -n "检查 Docker Compose... "
if docker compose version &> /dev/null; then
    docker compose version
else
    echo "未安装或版本过低"
    exit 1
fi

# 3. 端口检查
echo -n "检查端口 18789... "
if ss -tuln | grep -q :18789; then
    echo "已被占用"
else
    echo "可用"
fi

# 4. 磁盘空间检查
echo "检查磁盘空间... "
df -h ~ | tail -1

# 5. 内存检查
echo "检查内存... "
free -h

echo "=== 检查完成 ==="
```

## 下一步

环境准备完成后，请继续阅读 [deployment-guide.md](./deployment-guide.md) 开始部署流程。
