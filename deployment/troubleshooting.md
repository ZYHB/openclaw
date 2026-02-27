# 问题排查和解决方案

本文档记录在物理机上使用 Docker 部署 OpenClaw 时遇到的常见问题及解决方案。

## 目录

- [部署阶段问题](#部署阶段问题)
- [运行阶段问题](#运行阶段问题)
- [性能问题](#性能问题)
- [网络问题](#网络问题)
- [安全问题](#安全问题)
- [问题记录模板](#问题记录模板)

## 部署阶段问题

### 1. Docker 构建失败

#### 问题描述

```
ERROR [builder X/Y] RUN pnpm install --frozen-lockfile
------
> Error: Command failed: exit code 137
```

#### 原因

内存不足（OOM），Docker 构建过程被系统 kill。

#### 解决方案

```bash
# 方案 1：增加 Docker 内存限制
# 编辑 Docker Desktop 设置或配置 daemon.json

# 方案 2：使用 swap 空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# 永久生效：在 /etc/fstab 添加 /swapfile swap swap defaults 0 0

# 方案 3：限制构建时的内存使用
docker build \
  --memory=4g \
  --memory-swap=6g \
  -t openclaw:local \
  -f Dockerfile .
```

---

### 2. 权限错误 (EACCES)

#### 问题描述

```
Error: EACCES: permission denied, mkdir '/home/node/.openclaw'
```

#### 原因

挂载的目录权限与容器内用户（UID 1000）不匹配。

#### 解决方案

```bash
# 修复权限
sudo chown -R 1000:1000 ~/.openclaw

# 或者以 root 运行容器（不推荐，仅用于测试）
# 修改 docker-compose.yml，移除 `user: "1000:1000"` 或添加 `user: root`
```

---

### 3. 端口已被占用

#### 问题描述

```
Error: bind: address already in use
```

#### 原因

默认端口 18789 或 18790 已被其他进程占用。

#### 解决方案

```bash
# 查找占用端口的进程
sudo ss -tulnp | grep 18789

# 方案 1：停止占用端口的进程
sudo kill <PID>

# 方案 2：修改端口
# 编辑 .env 文件
OPENCLAW_GATEWAY_PORT=18791
OPENCLAW_BRIDGE_PORT=18792

# 方案 3：在同一网络下运行多个实例
# 修改每个实例的端口和配置目录
```

---

### 4. 镜像拉取失败

#### 问题描述

```
ERROR: failed to solve: node:22-bookworm: pull access denied
```

#### 原因

网络问题或 Docker registry 访问受限。

#### 解决方案

```bash
# 方案 1：配置 Docker 镜像加速器
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live"
  ]
}
EOF
sudo systemctl restart docker

# 方案 2：配置代理
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

# 方案 3：手动拉取基础镜像
docker pull node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935
```

---

## 运行阶段问题

### 5. 容器启动失败

#### 问题描述

```bash
$ docker compose up -d openclaw-gateway
ERROR: for openclaw-gateway  Cannot start service openclaw-gateway
```

#### 诊断步骤

```bash
# 查看详细错误
docker compose logs openclaw-gateway

# 检查容器状态
docker compose ps

# 尝试手动运行
docker compose run --rm openclaw-gateway node dist/index.js gateway
```

#### 常见原因和解决方案

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `config file not found` | 配置文件缺失 | 运行 `docker compose run --rm openclaw-cli onboard` |
| `invalid token` | Token 错误 | 检查 `.env` 中的 `OPENCLAW_GATEWAY_TOKEN` |
| `port already in use` | 端口冲突 | 修改端口或停止占用进程 |
| `permission denied` | 权限问题 | 修复 `~/.openclaw` 目录权限 |

---

### 6. 控制面板无法访问

#### 问题描述

浏览器打开 `http://server-ip:18789/` 显示：
- "无法访问此网站"
- "连接被拒绝"
- "unauthorized" (401)

#### 解决方案

```bash
# 1. 检查容器状态
docker compose ps openclaw-gateway

# 2. 检查端口监听
docker compose exec openclaw-gateway netstat -tuln | grep 18789

# 3. 检查防火墙
sudo ufw status
# 如果需要，允许端口
sudo ufw allow 18789/tcp

# 4. 检查 Token
echo $OPENCLAW_GATEWAY_TOKEN
# 重新生成 Token
docker compose run --rm openclaw-cli dashboard --no-open

# 5. 测试本地连接
curl -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" \
  http://127.0.0.1:18789/health
```

---

### 7. AI 模型连接失败

#### 问题描述

```
Error: Failed to connect to model provider API
```

#### 解决方案

```bash
# 1. 验证 API Key
docker compose run --rm openclaw-cli \
  models test --provider openai

# 2. 检查网络连接
docker compose exec openclaw-gateway \
  curl -I https://api.openai.com

# 3. 配置代理（如果需要）
# 编辑 ~/.openclaw/config.json
{
  "models": {
    "providers": [
      {
        "id": "openai",
        "httpProxy": "http://proxy.example.com:8080"
      }
    ]
  }
}

# 4. 重启 gateway
docker compose restart openclaw-gateway
```

---

### 8. 消息通道连接问题

#### WhatsApp

```bash
# QR 码不显示
docker compose run --rm openclaw-cli channels login --verbose

# 连接断开
docker compose run --rm openclaw-cli channels status --channel whatsapp
docker compose restart openclaw-gateway
```

#### Telegram

```bash
# Bot 无响应
# 1. 验证 token
docker compose run --rm openclaw-cli \
  channels test --channel telegram

# 2. 检查 webhook
docker compose exec openclaw-gateway \
  curl https://api.telegram.org/bot<token>/getWebhookInfo

# 3. 重新设置 webhook
docker compose run --rm openclaw-cli \
  channels reset --channel telegram
```

---

## 性能问题

### 9. 容器内存占用过高

#### 问题描述

容器被 OOM killer 终止或系统变慢。

#### 解决方案

```bash
# 1. 检查内存使用
docker stats openclaw-gateway

# 2. 限制容器内存
# 编辑 docker-compose.yml
services:
  openclaw-gateway:
    deploy:
      resources:
        limits:
          memory: 2G

# 3. 调整 Node.js 内存
# 修改 CMD
command: [
  "node",
  "--max-old-space-size=1536",
  "dist/index.js",
  "gateway"
]
```

---

### 10. 响应缓慢

#### 问题描述

AI 响应时间过长或超时。

#### 诊断

```bash
# 检查日志
docker compose logs -f openclaw-gateway | grep -i "timeout\|slow"

# 检查网络延迟
docker compose exec openclaw-gateway \
  ping -c 5 api.openai.com
```

#### 解决方案

```bash
# 1. 增加超时时间
# 编辑 ~/.openclaw/config.json
{
  "models": {
    "timeoutMs": 120000
  }
}

# 2. 使用更快的模型提供商
# 3. 启用缓存（如果支持）
```

---

## 网络问题

### 11. 容器无法访问外网

#### 问题描述

```
Error: getaddrinfo ENOTFOUND api.openai.com
```

#### 解决方案

```bash
# 1. 检查 DNS
docker compose exec openclaw-gateway cat /etc/resolv.conf

# 2. 修改 DNS
# 编辑 docker-compose.yml
services:
  openclaw-gateway:
    dns:
      - 8.8.8.8
      - 8.8.4.4

# 3. 检查防火墙/NAT
sudo iptables -L -n -v
```

---

### 12. 反向代理配置问题 (502 Bad Gateway)

#### 解决方案

```bash
# 1. 检查 upstream 地址
curl http://127.0.0.1:18789/health

# 2. 检查 Nginx 配置
sudo nginx -t

# 3. 查看 Nginx 日志
sudo tail -f /var/log/nginx/error.log

# 4. 确保使用正确的 proxy_set_header
location / {
    proxy_pass http://127.0.0.1:18789;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

---

## 安全问题

### 13. 未授权访问

#### 问题描述

控制面板可以被无 Token 访问。

#### 解决方案

```bash
# 1. 确保 Token 已设置
echo $OPENCLAW_GATEWAY_TOKEN

# 2. 检查配置
docker compose exec openclaw-gateway \
  cat /home/node/.openclaw/config.json | grep -i "token\|auth"

# 3. 重新生成 Token
openssl rand -hex 32 > /tmp/new-token
# 更新 .env 文件
docker compose up -d openclaw-gateway
```

---

### 14. 敏感信息泄露

#### 预防措施

```bash
# 1. 不要在日志中记录 API Key
docker compose logs openclaw-gateway | grep -i "sk-"  # 不应输出

# 2. 限制配置文件权限
chmod 600 ~/.openclaw/config.json
chmod 600 .env

# 3. 使用 secrets 管理（Docker Swarm）
echo "your-api-key" | docker secret create openai_api_key -
```

---

## 问题记录模板

当遇到新问题时，请使用以下模板记录：

```markdown
### 问题标题

**日期**：YYYY-MM-DD
**环境**：
- 操作系统：Ubuntu 22.04 LTS
- Docker 版本：24.0.7
- OpenClaw 版本：2026.2.26
- 分支：my-deploy

#### 问题描述
[详细描述问题现象]

#### 错误信息
```
[完整的错误日志]
```

#### 复现步骤
1.
2.
3.

#### 解决方案
[描述如何解决]

#### 相关资源
- Issue 链接：
- 文档链接：
- 相关提交：
```

---

## 获取诊断信息

当需要帮助时，收集以下信息：

```bash
#!/bin/bash
# diagnostic.sh - 收集诊断信息

OUTPUT_DIR="diagnostic-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "收集诊断信息到 $OUTPUT_DIR..."

# 1. 系统信息
uname -a > "$OUTPUT_DIR/system.txt"
docker --version > "$OUTPUT_DIR/docker-version.txt"
docker compose version > "$OUTPUT_DIR/compose-version.txt"

# 2. Docker 状态
docker ps -a > "$OUTPUT_DIR/docker-ps.txt"
docker stats --no-stream > "$OUTPUT_DIR/docker-stats.txt"

# 3. 容器日志
docker compose logs > "$OUTPUT_DIR/compose-logs.txt"
docker compose logs openclaw-gateway --tail=500 > "$OUTPUT_DIR/gateway-logs.txt"

# 4. 配置文件（移除敏感信息）
cat .env | sed 's/OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=***REMOVED***/' > "$OUTPUT_DIR/env.txt"
cat ~/.openclaw/config.json > "$OUTPUT_DIR/config.json"

# 5. 网络状态
ss -tulnp | grep 18789 > "$OUTPUT_DIR/network.txt"

# 6. 资源使用
free -h > "$OUTPUT_DIR/memory.txt"
df -h > "$OUTPUT_DIR/disk.txt"

echo "诊断信息已收集到 $OUTPUT_DIR/"
echo "请将此目录归档后提供给支持团队（注意移除敏感信息）"
```

---

## 参考资源

- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [Docker 故障排除](https://docs.docker.com/engine/troubleshooting/)
- [GitHub Issues](https://github.com/openclaw/openclaw/issues)
- [Discord 社区](https://discord.gg/clawd)
