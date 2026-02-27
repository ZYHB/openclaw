# Agent Sandbox 配置指南

Agent Sandbox 是 OpenClaw 的一个**核心安全功能**，用于在隔离的 Docker 容器中运行 Agent 工具，提高系统安全性。

## 目录

- [什么是 Agent Sandbox](#什么是-agent-sandbox)
- [为什么需要 Sandbox](#为什么需要-sandbox)
- [Sandbox 工作原理](#sandbox-工作原理)
- [构建沙箱镜像](#构建沙箱镜像)
- [配置 Sandbox](#配置-sandbox)
- [Sandbox 模式对比](#sandbox-模式对比)
- [工作空间访问](#工作空间访问)
- [工具权限控制](#工具权限控制)
- [安全最佳实践](#安全最佳实践)
- [故障排查](#故障排查)

## 什么是 Agent Sandbox

Agent Sandbox 允许 OpenClaw 在独立的 Docker 容器中运行 Agent 工具，与主 Gateway 容器隔离。这提供了：

- **安全隔离**：限制工具对主机系统的访问
- **资源控制**：限制 CPU、内存和磁盘使用
- **网络控制**：可选择禁用网络访问
- **临时文件**：工具创建的文件不会污染主机
- **可重复环境**：每个代理都有干净的工作环境

## 为什么需要 Sandbox

### 无 Sandbox 的问题

```json
// Agent 工具在 Gateway 容器中运行
{
  "exec": {
    "command": "rm -rf /home/node/.openclaw"
  }
}

// 危险操作可能影响：
// - Gateway 配置文件
// - 会话数据
// - 工作空间文件
```

### 使用 Sandbox 的好处

```json
// Agent 工具在隔离容器中运行
{
  "exec": {
    "command": "rm -rf /workspace"  // 只影响沙箱容器
  }
}

// 主机 Gateway 容器不受影响
```

## Sandbox 工作原理

```
┌─────────────────────────────────────────────────┐
│              Gateway 容器 (主机)                 │
│  - 运行 OpenClaw Gateway                        │
│  - 管理配置和会话                               │
│  - main 会话的工具直接运行                       │
└────────────┬────────────────────────────────────┘
             │
             │ Docker API
             ▼
┌─────────────────────────────────────────────────┐
│           Sandbox 容器 (隔离)                    │
│  - 非 main 会话的工具在沙箱中运行                │
│  - 独立的工作空间                               │
│  - 受限的网络和资源访问                         │
└─────────────────────────────────────────────────┘
```

### 默认行为

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 镜像 | `openclaw-sandbox:bookworm-slim` | 沙箱基础镜像 |
| 容器范围 | `agent` | 每个代理一个容器 |
| 工作空间访问 | `none` | 使用 `~/.openclaw/sandboxes` |
| 自动清理 | 空闲>24h 或 年龄>7天 | 自动删除容器 |
| 网络 | `none` | 无网络访问（增强安全） |

## 构建沙箱镜像

### 基础沙箱镜像

```bash
# 默认沙箱镜像（最小化）
./scripts/sandbox-setup.sh
```

这会创建 `openclaw-sandbox:bookworm-slim` 镜像，包含：
- Debian Bookworm Slim 基础系统
- Node.js 运行时
- 基础工具（curl, wget, git）

### 常用工具的镜像

```bash
# 包含常用开发工具（Node, Go, Rust, Python）
./scripts/sandbox-common-setup.sh
```

额外包含：
- `gcc`, `make`, `build-essential`
- `python3`, `pip`
- `golang`
- `rustc`, `cargo`

### 带浏览器的镜像

```bash
# 包含 Chromium/Playwright 浏览器
./scripts/sandbox-browser-setup.sh
```

额外包含：
- Chromium 浏览器
- Playwright 库
- 相关依赖和字体

### 验证镜像

```bash
# 查看沙箱镜像
docker images | grep openclaw-sandbox

# 测试沙箱容器
docker run --rm openclaw-sandbox:bookworm-slim node --version
```

## 配置 Sandbox

编辑配置文件 `~/.openclaw/config.json`：

### 基础配置

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",      // off | non-main | all
        "scope": "agent",         // session | agent | shared
        "workspaceAccess": "none" // none | ro | rw
      }
    }
  }
}
```

### 完整配置示例

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "scope": "agent",
        "workspaceAccess": "none",
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim",
          "workdir": "/workspace",
          "readOnlyRoot": true,
          "tmpfs": ["/tmp", "/var/tmp", "/run"],
          "network": "none",
          "user": "1000:1000",
          "memory": "1g",
          "cpus": 1,
          "memorySwap": "2g",
          "pidsLimit": 512
        }
      }
    }
  }
}
```

### 配置选项说明

| 选项 | 类型 | 说明 |
|------|------|------|
| `mode` | string | 何时使用沙箱：`off` / `non-main` / `all` |
| `scope` | string | 容器共享范围：`session` / `agent` / `shared` |
| `workspaceAccess` | string | 工作空间访问：`none` / `ro` / `rw` |
| `docker.image` | string | 沙箱镜像名称 |
| `docker.workdir` | string | 容器工作目录 |
| `docker.readOnlyRoot` | boolean | 根文件系统只读 |
| `docker.tmpfs` | array | tmpfs 挂载点 |
| `docker.network` | string | 网络模式：`none` / `bridge` / `host` |
| `docker.user` | string | 容器用户 (UID:GID) |
| `docker.memory` | string | 内存限制 |
| `docker.cpus` | number | CPU 限制 |
| `docker.memorySwap` | string | 交换空间限制 |
| `docker.pidsLimit` | number | 进程数限制 |

## Sandbox 模式对比

### 模式选择

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| `off` | 禁用沙箱 | 完全信任的本地环境 |
| `non-main` | 仅非 main 会话隔离 | **推荐**：保护个人会话 |
| `all` | 所有会话隔离 | 高安全性要求 |

### 示例配置

#### 1. 完全禁用（不推荐用于生产）

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "off"
      }
    }
  }
}
```

#### 2. 仅隔离代理会话（推荐）

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "scope": "agent"
      }
    }
  }
}
```

#### 3. 所有会话隔离（高安全）

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",
        "scope": "session"
      }
    }
  }
}
```

## 工作空间访问

控制沙箱容器对代理工作空间的访问权限。

### 访问模式

| 模式 | 说明 | 风险 |
|------|------|------|
| `none` | 使用独立沙箱工作空间 | 最安全 |
| `ro` | 只读挂载代理工作空间 | 中等 |
| `rw` | 读写挂载代理工作空间 | 较高 |

### 配置示例

#### 独立工作空间（最安全，推荐）

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "workspaceAccess": "none"
      }
    }
  }
}
```

沙箱使用 `~/.openclaw/sandboxes/<agentId>/` 作为工作目录。

#### 只读访问

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "workspaceAccess": "ro"
      }
    }
  }
}
```

沙箱可以读取代理工作空间，但无法修改。

#### 读写访问（谨慎使用）

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "workspaceAccess": "rw"
      }
    }
  }
}
```

沙箱可以完全访问和修改代理工作空间。

## 工具权限控制

即使使用沙箱，也可以进一步控制允许使用的工具。

### 默认工具权限

```json
{
  "tools": {
    "sandbox": {
      "tools": {
        "allow": ["exec", "process", "read", "write", "edit"],
        "deny": ["browser", "canvas", "nodes", "cron", "discord", "gateway"]
      }
    }
  }
}
```

### 自定义工具白名单

```json
{
  "tools": {
    "sandbox": {
      "tools": {
        "allow": ["read", "write"],
        "deny": ["*"]
      }
    }
  }
}
```

### 工具列表

| 工具 | 说明 | 默认 |
|------|------|------|
| `exec` | 执行 Shell 命令 | ✅ 允许 |
| `process` | 管理进程 | ✅ 允许 |
| `read` | 读取文件 | ✅ 允许 |
| `write` | 写入文件 | ✅ 允许 |
| `edit` | 编辑文件 | ✅ 允许 |
| `browser` | 浏览器自动化 | ❌ 拒绝 |
| `canvas` | Canvas 工具 | ❌ 拒绝 |
| `nodes` | 节点管理 | ❌ 拒绝 |
| `cron` | 定时任务 | ❌ 拒绝 |
| `discord` | Discord 集成 | ❌ 拒绝 |
| `gateway` | Gateway 控制 | ❌ 拒绝 |

## 安全最佳实践

### 1. 使用只读根文件系统

```json
{
  "docker": {
    "readOnlyRoot": true,
    "tmpfs": ["/tmp", "/var/tmp", "/run"]
  }
}
```

### 2. 禁用网络访问

```json
{
  "docker": {
    "network": "none"
  }
}
```

如果需要网络访问（如下载依赖），使用：

```json
{
  "docker": {
    "network": "bridge"
  }
}
```

### 3. 限制资源使用

```json
{
  "docker": {
    "memory": "1g",
    "cpus": 1,
    "memorySwap": "2g",
    "pidsLimit": 512
  }
}
```

### 4. 使用非 root 用户

```json
{
  "docker": {
    "user": "1000:1000"
  }
}
```

### 5. 定期清理容器

默认情况下，空闲超过 24 小时或创建超过 7 天的沙箱容器会自动清理。

手动清理：

```bash
# 列出所有沙箱容器
docker ps -a | grep openclaw-sandbox

# 删除所有沙箱容器
docker ps -a | grep openclaw-sandbox | awk '{print $1}' | xargs docker rm -f
```

## 故障排查

### 问题 1：沙箱容器无法启动

**错误信息：**

```
Error: Cannot start sandbox container
```

**解决方案：**

```bash
# 1. 检查沙箱镜像是否存在
docker images | grep openclaw-sandbox

# 2. 重建沙箱镜像
./scripts/sandbox-setup.sh

# 3. 检查 Docker 资源
docker system df
docker system prune -a
```

### 问题 2：沙箱中无法访问网络

**预期行为（网络禁用时）：**

```json
{
  "docker": {
    "network": "none"
  }
}
```

如果需要网络访问：

```bash
# 编辑配置
nano ~/.openclaw/config.json

# 修改为:
{
  "docker": {
    "network": "bridge"
  }
}

# 重启 gateway
docker compose restart openclaw-gateway
```

### 问题 3：权限错误 (EACCES)

**错误信息：**

```
Error: EACCES: permission denied, mkdir '/workspace'
```

**解决方案：**

```bash
# 检查沙箱用户 ID
docker run --rm openclaw-sandbox:bookworm-slim id

# 确保主机目录权限正确
sudo chown -R 1000:1000 ~/.openclaw/sandboxes
```

### 问题 4：磁盘空间不足

**错误信息：**

```
Error: No space left on device
```

**解决方案：**

```bash
# 1. 清理未使用的 Docker 资源
docker system prune -a --volumes

# 2. 清理沙箱容器
docker ps -a | grep openclaw-sandbox | awk '{print $1}' | xargs docker rm -f

# 3. 检查磁盘使用
df -h
du -sh ~/.openclaw/sandboxes/*
```

### 问题 5：沙箱容器未自动清理

**检查配置：**

```bash
# 查看当前配置
docker compose exec openclaw-gateway \
  cat /home/node/.openclaw/config.json | jq '.agents.defaults.sandbox'
```

**手动清理：**

```bash
# 删除旧的沙箱容器
docker ps -a --filter "label=openclaw-sandbox" \
  --filter "until=24h" -q | xargs docker rm -f

# 或按创建时间清理
docker ps -a --filter "label=openclaw-sandbox" \
  | grep "days ago" | awk '{print $1}' | xargs docker rm -f
```

## 调试和监控

### 查看沙箱容器日志

```bash
# 列出所有沙箱容器
docker ps -a --filter "label=openclaw-sandbox"

# 查看特定容器日志
docker logs <container-id>

# 实时跟踪日志
docker logs -f <container-id>
```

### 进入沙箱容器调试

```bash
# 进入运行中的沙箱容器
docker exec -it <container-id> /bin/bash

# 查看工作目录
ls -la /workspace

# 查看环境变量
env | sort

# 查看进程
ps aux
```

### 监控资源使用

```bash
# 实时监控所有沙箱容器
docker stats --filter "label=openclaw-sandbox"

# 查看特定容器资源使用
docker stats <container-id>
```

## 配置验证

### 验证沙箱配置

```bash
# 运行诊断
docker compose run --rm openclaw-cli doctor

# 检查配置语法
docker compose run --rm openclaw-cli config validate
```

### 测试沙箱功能

```bash
# 1. 创建测试代理（需要通过 Web UI 或 CLI）
# docker compose run --rm openclaw-cli agents create

# 2. 在沙箱中运行命令
# 通过 Web UI 或消息通道发送测试消息

# 3. 检查沙箱容器是否创建
docker ps -a --filter "label=openclaw-sandbox"

# 4. 查看沙箱日志
docker logs <container-id>
```

## 高级配置

### 特定代理的沙箱配置

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "scope": "agent"
      }
    },
    "specific": {
      "agent-id": {
        "sandbox": {
          "mode": "all",
          "workspaceAccess": "rw"
        }
      }
    }
  }
}
```

### 自定义沙箱镜像

```bash
# 构建自定义沙箱镜像
cat > Dockerfile.sandbox <<EOF
FROM openclaw-sandbox:bookworm-slim

# 安装额外工具
RUN apt-get update && apt-get install -y \
  ffmpeg \
  imagemagick \
  && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /workspace

# 切换到非 root 用户
USER 1000:1000

CMD ["/bin/bash"]
EOF

# 构建镜像
docker build -f Dockerfile.sandbox -t openclaw-sandbox:custom .

# 更新配置使用自定义镜像
# 编辑 ~/.openclaw/config.json
# {
#   "docker": {
#     "image": "openclaw-sandbox:custom"
#   }
# }
```

## 相关文档

- [官方 Sandboxing 文档](https://docs.openclaw.ai/gateway/sandboxing)
- [Docker 安全最佳实践](https://docs.docker.com/engine/security/)
- [configuration.md](./configuration.md) - 通用配置参考
- [troubleshooting.md](./troubleshooting.md) - 问题排查

## 常见问题

### Q: 沙箱会影响性能吗？

A: 会有轻微的性能开销（容器启动和隔离），但通常可以忽略不计。对于频繁的工具调用，使用 `scope: shared` 可以减少容器创建开销。

### Q: 可以在沙箱中使用 GUI 应用吗？

A: 默认沙箱没有显示服务器。如需使用 GUI 应用，需要：
1. 使用带浏览器的沙箱镜像
2. 配置 X11 转发或 VNC
3. 增加内存限制

### Q: 如何共享数据到沙箱？

A: 有几种方式：
1. 使用 `workspaceAccess: ro/rw` 挂载工作空间
2. 在 `docker.volumes` 中添加额外挂载
3. 通过文件复制工具传输

### Q: 沙箱容器会被持久化吗？

A: 不会。沙箱容器是临时的，会根据配置自动清理。重要数据应该保存在工作空间或持久化卷中。

---

**最后更新：** 2026-02-27
**相关文档：** https://docs.openclaw.ai/gateway/sandboxing
