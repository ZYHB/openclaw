# 配置参考文档

本文档提供 OpenClaw Docker 部署的详细配置说明和参考。

## 目录

- [环境变量配置](#环境变量配置)
- [Docker Compose 配置](#docker-compose-配置)
- [OpenClaw 配置文件](#openclaw-配置文件)
- [通道配置](#通道配置)
- [模型配置](#模型配置)
- [安全配置](#安全配置)

## 环境变量配置

### 必需环境变量

在项目根目录创建 `.env` 文件：

```bash
# ========================================
# 必需配置
# ========================================

# Gateway 访问 Token（必需，用于控制面板认证）
OPENCLAW_GATEWAY_TOKEN=your-secure-random-token-here

# ========================================
# 路径配置
# ========================================

# 配置目录路径
OPENCLAW_CONFIG_DIR=$HOME/.openclaw

# 工作空间目录路径
OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace

# ========================================
# 网络配置
# ========================================

# Gateway WebSocket 端口（默认 18789）
OPENCLAW_GATEWAY_PORT=18789

# Bridge 端口（默认 18790）
OPENCLAW_BRIDGE_PORT=18790

# Gateway 绑定地址
# - loopback: 仅本地访问 (127.0.0.1)
# - lan: 局域网访问 (0.0.0.0)
OPENCLAW_GATEWAY_BIND=lan

# ========================================
# 会话密钥（自动生成，通常无需手动设置）
# ========================================

CLAUDE_AI_SESSION_KEY=ai-session-key-random
CLAUDE_WEB_SESSION_KEY=web-session-key-random
CLAUDE_WEB_COOKIE=web-cookie-secret-random
```

### 生成安全 Token

```bash
# Gateway Token (32 字节十六进制)
openssl rand -hex 32

# 会话密钥 (16 字节十六进制)
openssl rand -hex 16
```

### 可选环境变量

```bash
# ========================================
# 可选配置
# ========================================

# 构建时额外安装的 APT 包（官方推荐）
OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg git jq"

# 额外的挂载点（逗号分隔）
# 格式：source:target[:options]
# ro = 只读，rw = 读写
OPENCLAW_EXTRA_MOUNTS="$HOME/Documents:/home/node/documents:rw,$HOME/.codex:/home/node/.codex:ro"

# 持久化卷名称（使用 Docker 卷持久化 /home/node）
OPENCLAW_HOME_VOLUME=openclaw_home

# Node.js 内存限制（MB）
NODE_OPTIONS=--max-old-space-size=2048

# 开发模式
OPENCLAW_DEV_MODE=0

# 日志级别
# - trace | debug | info | warn | error
LOG_LEVEL=info
```

### 官方推荐环境变量说明

根据官方文档，以下环境变量可以在运行 `./docker-setup.sh` 前设置来自定义部署：

#### OPENCLAW_DOCKER_APT_PACKAGES

**用途：** 在镜像构建时安装系统包

**常用包：**
- `ffmpeg` - 音视频处理
- `build-essential` - 编译工具
- `git curl jq` - 开发工具
- `python3 python3-pip` - Python 支持

**示例：**
```bash
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential"
./docker-setup.sh
```

#### OPENCLAW_EXTRA_MOUNTS

**用途：** 将主机目录挂载到容器中

**格式：** `source:target[:options]`（逗号分隔，无空格）

**选项：**
- `ro` - 只读挂载
- `rw` - 读写挂载

**注意事项：**
- macOS/Windows: 路径必须在 Docker Desktop 中共享
- 修改后需要重新运行 `./docker-setup.sh` 生成 `docker-compose.extra.yml`

**示例：**
```bash
export OPENCLAW_EXTRA_MOUNTS="$HOME/Documents:/home/node/documents:rw,$HOME/.codex:/home/node/.codex:ro"
./docker-setup.sh
```

#### OPENCLAW_HOME_VOLUME

**用途：** 使用 Docker 卷持久化 `/home/node` 目录

**效果：**
- 创建命名卷 `openclaw_home`
- 挂载到容器的 `/home/node`
- 浏览器下载和工具缓存会持久化
- 容器删除后数据不丢失

**示例：**
```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
./docker-setup.sh
```

**组合使用：**
```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
export OPENCLAW_EXTRA_MOUNTS="$HOME/.codex:/home/node/.codex:ro"
./docker-setup.sh
```

## Docker Compose 配置

### 基础配置 (docker-compose.yml)

```yaml
services:
  # Gateway 服务
  openclaw-gateway:
    image: ${OPENCLAW_IMAGE:-openclaw:local}
    container_name: openclaw-gateway
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      CLAUDE_AI_SESSION_KEY: ${CLAUDE_AI_SESSION_KEY}
      CLAUDE_WEB_SESSION_KEY: ${CLAUDE_WEB_SESSION_KEY}
      CLAUDE_WEB_COOKIE: ${CLAUDE_WEB_COOKIE}
      NODE_ENV: production
      LOG_LEVEL: ${LOG_LEVEL:-info}
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
    ports:
      - "${OPENCLAW_GATEWAY_PORT:-18789}:18789"
      - "${OPENCLAW_BRIDGE_PORT:-18790}:18790"
    restart: unless-stopped
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "${OPENCLAW_GATEWAY_BIND:-lan}",
        "--port",
        "18789"
      ]
    healthcheck:
      test: ["CMD", "node", "dist/index.js", "health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # CLI 容器（用于命令执行）
  openclaw-cli:
    image: ${OPENCLAW_IMAGE:-openclaw:local}
    container_name: openclaw-cli
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      BROWSER: echo  # 禁用浏览器打开
      CLAUDE_AI_SESSION_KEY: ${CLAUDE_AI_SESSION_KEY}
      CLAUDE_WEB_SESSION_KEY: ${CLAUDE_WEB_SESSION_KEY}
      CLAUDE_WEB_COOKIE: ${CLAUDE_WEB_COOKIE}
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
    stdin_open: true
    tty: true
    entrypoint: ["node", "dist/index.js"]
```

### 生产环境配置

创建 `docker-compose.prod.yml`：

```yaml
services:
  openclaw-gateway:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    restart: always

  openclaw-cli:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
```

### 高级网络配置

```yaml
services:
  openclaw-gateway:
    networks:
      - openclaw-net
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  openclaw-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

## OpenClaw 配置文件

配置文件位置：`~/.openclaw/config.json`

### 基础配置

```json
{
  "$schema": "https://openclaw.ai/schema/config.json",
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "token": "your-token-here"
  },
  "agents": {
    "defaults": {
      "model": "anthropic:claude-sonnet-4-20250514",
      "maxToolRounds": 20,
      "timeoutMs": 120000
    }
  },
  "models": {
    "providers": []
  },
  "channels": {}
}
```

### 完整配置示例

```json
{
  "$schema": "https://openclaw.ai/schema/config.json",

  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789
  },

  "agents": {
    "defaults": {
      "model": "anthropic:claude-sonnet-4-20250514",
      "maxToolRounds": 20,
      "timeoutMs": 120000,
      "temperature": 0.7,
      "maxTokens": 8192,
      "thinkingMode": "high",
      "sandbox": {
        "mode": "non-main",
        "scope": "agent",
        "workspaceAccess": "none",
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim",
          "readOnlyRoot": true,
          "network": "none",
          "tmpfs": ["/tmp", "/var/tmp"]
        }
      }
    }
  },

  "models": {
    "providers": [
      {
        "id": "anthropic",
        "baseUrl": "https://api.anthropic.com",
        "apiKey": "sk-ant-xxxxx"
      },
      {
        "id": "openai",
        "baseUrl": "https://api.openai.com/v1",
        "apiKey": "sk-xxxxx"
      }
    ],
    "default": "anthropic:claude-sonnet-4-20250514"
  },

  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing",
      "allowFrom": ["*"]
    },
    "telegram": {
      "enabled": true,
      "bots": [
        {
          "token": "123456:ABC-DEF...",
          "dmPolicy": "open"
        }
      ]
    }
  },

  "tools": {
    "sandbox": {
      "tools": {
        "allow": ["exec", "read", "write", "edit"],
        "deny": ["browser", "nodes", "canvas"]
      }
    }
  },

  "cron": {
    "enabled": true,
    "jobs": []
  },

  "logging": {
    "level": "info",
    "file": "/home/node/.openclaw/logs/gateway.log"
  }
}
```

## 通道配置

### WhatsApp

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing",
      "allowFrom": ["+1234567890", "+0987654321"],
      "autoApproveOnReply": true
    }
  }
}
```

### Telegram

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "bots": [
        {
          "token": "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11",
          "dmPolicy": "pairing",
          "allowFrom": ["*"],
          "commands": {
            "allow": ["*"]
          }
        }
      ]
    }
  }
}
```

### Discord

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "bots": [
        {
          "token": "YOUR_DISCORD_BOT_TOKEN_HERE",
          "dmPolicy": "pairing",
          "allowFrom": ["*"],
          "intents": ["guilds", "guildMessages", "directMessages"]
        }
      ]
    }
  }
}
```

## 模型配置

### Anthropic Claude

```json
{
  "models": {
    "providers": [
      {
        "id": "anthropic",
        "baseUrl": "https://api.anthropic.com",
        "apiKey": "sk-ant-api03-xxxxx",
        "models": [
          {
            "id": "claude-sonnet-4-20250514",
            "name": "Claude Sonnet 4"
          },
          {
            "id": "claude-opus-4-20250514",
            "name": "Claude Opus 4"
          }
        ]
      }
    ],
    "default": "anthropic:claude-sonnet-4-20250514"
  }
}
```

### OpenAI GPT

```json
{
  "models": {
    "providers": [
      {
        "id": "openai",
        "baseUrl": "https://api.openai.com/v1",
        "apiKey": "sk-proj-xxxxx",
        "models": [
          {
            "id": "gpt-4o",
            "name": "GPT-4o"
          },
          {
            "id": "gpt-4o-mini",
            "name": "GPT-4o Mini"
          }
        ]
      }
    ]
  }
}
```

### 自定义提供商（如 OpenAI 兼容 API）

```json
{
  "models": {
    "providers": [
      {
        "id": "custom-llm",
        "baseUrl": "https://your-api-endpoint.com/v1",
        "apiKey": "your-api-key",
        "headers": {
          "X-Custom-Header": "value"
        }
      }
    ]
  }
}
```

### 代理配置

```json
{
  "models": {
    "providers": [
      {
        "id": "openai",
        "baseUrl": "https://api.openai.com/v1",
        "apiKey": "sk-xxxxx",
        "httpProxy": "http://proxy.example.com:8080",
        "httpsProxy": "http://proxy.example.com:8080"
      }
    ]
  }
}
```

## 安全配置

### Token 认证

```json
{
  "gateway": {
    "token": "your-secure-random-token",
    "allowUnauthenticated": false
  }
}
```

### 设备配对

```json
{
  "gateway": {
    "requireDevicePairing": true,
    "deviceApproval": "manual"
  }
}
```

### DM 策略

| 策略 | 说明 |
|------|------|
| `"open"` | 允许所有消息（危险） |
| `"pairing"` | 需要配对码（推荐） |
| `"block"` | 阻止所有 DM |

```json
{
  "channels": {
    "telegram": {
      "bots": [{
        "token": "...",
        "dmPolicy": "pairing",
        "allowFrom": ["+1234567890"]
      }]
    }
  }
}
```

### 命令白名单

```json
{
  "channels": {
    "telegram": {
      "bots": [{
        "token": "...",
        "commands": {
          "allow": ["help", "status", "summary"],
          "deny": ["exec", "bash"]
        }
      }]
    }
  }
}
```

## 性能优化

### 内存限制

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "docker": {
          "memory": "1g",
          "memorySwap": "2g"
        }
      }
    }
  }
}
```

### 并发控制

```json
{
  "gateway": {
    "maxConcurrentSessions": 10,
    "queueTimeoutMs": 30000
  }
}
```

## 日志配置

```json
{
  "logging": {
    "level": "info",
    "file": "/home/node/.openclaw/logs/gateway.log",
    "maxFiles": 7,
    "maxSize": "100M"
  }
}
```

## 配置验证

```bash
# 验证配置文件语法
docker compose run --rm openclaw-cli \
  config validate

# 检查配置
docker compose run --rm openclaw-cli doctor

# 测试模型连接
docker compose run --rm openclaw-cli \
  models test --provider anthropic
```

## 环境特定配置

### 开发环境

```bash
# .env.development
OPENCLAW_GATEWAY_BIND=loopback
LOG_LEVEL=debug
OPENCLAW_DEV_MODE=1
```

### 生产环境

```bash
# .env.production
OPENCLAW_GATEWAY_BIND=lan
LOG_LEVEL=warn
NODE_ENV=production
```

## 配置最佳实践

1. **永远使用环境变量存储敏感信息**（API Key, Token）
2. **限制容器资源**防止资源耗尽
3. **启用日志轮转**防止磁盘填满
4. **定期备份配置**和数据
5. **使用版本控制**管理配置变更（排除敏感信息）
6. **分离配置文件**（开发/生产）
7. **使用强随机 Token**（至少 32 字节）
8. **启用设备配对**用于远程访问
9. **配置合理的超时**防止挂起
10. **监控日志**及早发现问题

---

## 相关文档

- [deployment-guide.md](./deployment-guide.md) - 部署步骤
- [troubleshooting.md](./troubleshooting.md) - 问题排查
- [prerequisites.md](./prerequisites.md) - 前置要求
