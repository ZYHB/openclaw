# ClawDock 使用指南

ClawDock 是 OpenClaw 官方提供的 Shell 助手工具，通过简短的别名简化 Docker Compose 命令，让日常运维更加高效。
https://github.com/openclaw/openclaw/blob/main/scripts/shell-helpers/README.md
## 目录

- [什么是 ClawDock](#什么是-clawdock)
- [安装步骤](#安装步骤)
- [首次使用流程](#首次使用流程)
- [可用命令](#可用命令)
- [使用示例](#使用示例)
- [故障排查](#故障排查)

---

## 什么是 ClawDock

### 核心价值

将冗长的 Docker Compose 命令简化为易记的别名：

```bash
# ❌ 之前：需要输入完整命令
docker compose up -d openclaw-gateway

# ✅ 现在：只需简短别名
clawdock-start
```

### 主要优势

- ✅ **简化命令**：20+ 条别名替代复杂的 docker compose 命令
- ✅ **自动定位**：自动检测 OpenClaw 项目目录
- ✅ **官方支持**：由 OpenClaw 官方维护
- ✅ **开源免费**：完全开源，可自由定制

---

## 安装步骤

### 前置要求

- 已安装 Docker 和 Docker Compose v2
- 已完成 OpenClaw 的 Docker 部署
- 使用 zsh 或 bash shell

### 安装方法

```bash
# 步骤 1：创建 ClawDock 目录
mkdir -p ~/.clawdock

# 步骤 2：下载官方脚本
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh

# 步骤 3：添加到 shell 配置
# ====== zsh 用户（macOS 默认）======
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc
source ~/.zshrc

# ====== bash 用户 ======
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.bashrc
source ~/.bashrc
```

### 验证安装

```bash
# 重新加载 shell 配置后
source ~/.zshrc  # 或 source ~/.bashrc

# 测试安装
clawdock-help

# 如果看到命令列表，说明安装成功！
```

---

## 首次使用流程

安装完成后，第一次使用 ClawDock 时需要完成几个设置步骤。

### 🔍 自动检测 OpenClaw 目录

**当你第一次运行任何 ClawDock 命令时**，它会自动检测你的 OpenClaw 目录：

1. **检查常见路径**：
   - `~/openclaw`
   - `~/workspace/openclaw`
   - `~/projects/openclaw`
   - `~/dev/openclaw`
   - `~/code/openclaw`
   - `~/src/openclaw`

2. **询问确认**：如果找到目录，会提示你确认

3. **保存配置**：确认后保存到 `~/.clawdock/config`

4. **后续使用**：之后直接使用保存的路径，无需重复设置

### 📋 首次设置步骤

```bash
# 步骤 1：首次启动（会触发目录检测）
clawdock-start

# 如果看到提示：
# 🦞 Found OpenClaw at: /Users/xxx/openclaw
# Save this path? [Y/n]:
# 输入 Y 确认

# 步骤 2：修复 Token
clawdock-fix-token

# 步骤 3：打开控制面板
clawdock-dashboard

# 使用输出的 Token 登录控制面板
```

### 🔐 设备配对流程

如果你在访问控制面板时看到 **"unauthorized"** 或 **"pairing required"** 错误：

```bash
# 步骤 1：列出待配对设备
clawdock-devices

# 输出示例：
# Pending device requests:
#   - ID: abc123-def456
#     Name: "My MacBook"
#     Requested at: 2026-02-27 10:30:00

# 步骤 2：批准设备配对
clawdock-approve abc123-def456

# 步骤 3：重新打开控制面板
clawdock-dashboard
```

### ⚙️ 自定义目录位置

如果你的 OpenClaw 项目不在常见路径中：

**方法 1：临时指定**

```bash
export CLAWDOCK_DIR=/custom/path/to/openclaw
clawdock-start
```

**方法 2：永久设置**

```bash
# 添加到 shell 配置
echo 'export CLAWDOCK_DIR=/Users/aosom/Documents/yhui/github/ZYHB/openclaw' >> ~/.zshrc
source ~/.zshrc

# 保存到 ClawDock 配置
clawdock-start  # 会自动保存到 ~/.clawdock/config
```

**方法 3：手动编辑配置文件**

```bash
# 直接编辑配置文件
echo 'CLAWDOCK_DIR="/Users/aosom/Documents/yhui/github/ZYHB/openclaw"' > ~/.clawdock/config

# 验证配置
cat ~/.clawdock/config
```

### 🎯 完整首次使用示例

```bash
# ====== 完整的首次设置流程 ======

# 1. 安装 ClawDock（如果还没安装）
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc
source ~/.zshrc

# 2. 如果项目不在常见路径，设置环境变量
export CLAWDOCK_DIR=/Users/aosom/Documents/yhui/github/ZYHB/openclaw

# 3. 启动服务（首次运行会保存路径）
clawdock-start
# > 🦞 Found OpenClaw at: /Users/aosom/Documents/yhui/github/ZYHB/openclaw
# > Save this path? [Y/n]: Y
# > ✓ Path saved to ~/.clawdock/config

# 4. 修复/验证 Token
clawdock-fix-token
# > Gateway Token: abc123def456...

# 5. 打开控制面板
clawdock-dashboard
# > Opening dashboard: http://127.0.0.1:18789/?token=abc123...

# 6. 如果显示 "pairing required"，批准设备
clawdock-devices      # 查看待配对设备
clawdock-approve <id> # 批准设备

# 7. 完成！现在可以正常使用了
```

---

## 可用命令

ClawDock 提供 **20+ 条命令**，按功能分类如下：

### 1️⃣ 基础控制命令

| 命令 | 功能 | Docker Compose 等价命令 |
|------|------|------------------------|
| `clawdock-start` | 启动 OpenClaw Gateway | `docker compose up -d openclaw-gateway` |
| `clawdock-stop` | 停止所有服务 | `docker compose down` |
| `clawdock-restart` | 重启 Gateway | `docker compose restart openclaw-gateway` |
| `clawdock-logs` | 查看实时日志 | `docker compose logs -f openclaw-gateway` |
| `clawdock-ps` | 查看容器状态 | `docker compose ps` |

**使用示例：**

```bash
# 启动服务
clawdock-start

# 查看日志
clawdock-logs

# 重启服务
clawdock-restart

# 停止服务
clawdock-stop
```

---

### 2️⃣ Web UI 和访问命令

| 命令 | 功能 | Docker Compose 等价命令 |
|------|------|------------------------|
| `clawdock-dashboard` | 打开控制面板（浏览器） | `docker compose run --rm openclaw-cli dashboard` |
| `clawdock-devices` | 列出待配对设备 | `docker compose run --rm openclaw-cli devices list` |
| `clawdock-approve` | 批准设备配对 | `docker compose run --rm openclaw-cli devices approve <id>` |
| `clawdock-token` | 获取访问 Token | 从 `.env` 文件读取 `OPENCLAW_GATEWAY_TOKEN` |

**使用示例：**

```bash
# 打开控制面板
clawdock-dashboard

# 查看待配对设备
clawdock-devices

# 批准设备（使用设备 ID）
clawdock-approve abc123-def456

# 获取访问 Token
clawdock-token
```

---

### 3️⃣ 容器交互命令

| 命令 | 功能 | Docker Compose 等价命令 |
|------|------|------------------------|
| `clawdock-shell` | 进入 Gateway 容器的 Shell | `docker compose exec openclaw-gateway bash` |
| `clawdock-cli` | 运行 CLI 命令 | `docker compose run --rm openclaw-cli <args>` |
| `clawdock-exec` | 在容器中执行命令 | `docker compose exec openclaw-gateway <cmd>` |

**使用示例：**

```bash
# 进入容器 Shell
clawdock-shell

# 运行 CLI 命令
clawdock-cli doctor
clawdock-cli config validate

# 在容器中执行命令
clawdock-exec node --version
```

---

### 4️⃣ 维护和更新命令

| 命令 | 功能 | Docker Compose 等价命令 |
|------|------|------------------------|
| `clawdock-rebuild` | 重新构建镜像 | `docker compose build && docker compose up -d` |
| `clawdock-clean` | 清理容器和镜像 | `docker compose down -v && docker rmi openclaw:local` |
| `clawdock-pull` | 拉取最新代码 | `git pull` |
| `clawdock-update` | 更新并重启 | `git pull && docker compose build && docker compose up -d` |

**使用示例：**

```bash
# 重新构建镜像
clawdock-rebuild

# 清理所有容器和镜像
clawdock-clean

# 更新到最新代码
clawdock-update
```

---

### 5️⃣ 诊断和健康检查命令

| 命令 | 功能 | Docker Compose 等价命令 |
|------|------|------------------------|
| `clawdock-health` | 健康检查 | `docker compose exec openclaw-gateway node dist/index.js health` |
| `clawdock-doctor` | 运行诊断工具 | `docker compose run --rm openclaw-cli doctor` |
| `clawdock-stats` | 查看资源使用 | `docker stats openclaw-gateway` |
| `clawdock-inspect` | 检查容器详情 | `docker inspect openclaw-gateway` |

**使用示例：**

```bash
# 健康检查
clawdock-health

# 运行诊断
clawdock-doctor

# 查看资源使用情况
clawdock-stats
```

---

### 6️⃣ 实用工具命令

| 命令 | 功能 | 说明 |
|------|------|------|
| `clawdock-cd` | 进入 OpenClaw 目录 | 自动定位项目目录 |
| `clawdock-pwd` | 显示 OpenClaw 目录 | 显示当前项目路径 |
| `clawdock-help` | 显示所有命令 | 列出可用命令清单 |
| `clawdock-version` | 显示版本信息 | 显示 ClawDock 版本 |

**使用示例：**

```bash
# 快速进入项目目录
clawdock-cd

# 显示项目路径
clawdock-pwd

# 查看帮助
clawdock-help

# 查看版本
clawdock-version
```

---

### 7️⃣ 高级命令

| 命令 | 功能 | Docker Compose 等价命令 |
|------|------|------------------------|
| `clawdock-logs-all` | 查看所有容器日志 | `docker compose logs -f` |
| `clawdock-restart-all` | 重启所有容器 | `docker compose restart` |
| `clawdock-stop-all` | 停止所有容器 | `docker compose stop` |
| `clawdock-env` | 显示环境变量 | 显示 `.env` 文件内容 |

**使用示例：**

```bash
# 查看所有服务日志
clawdock-logs-all

# 重启所有容器
clawdock-restart-all

# 查看环境变量
clawdock-env
```

---

## 使用示例

### 典型工作流

```bash
# ====== 场景 1：首次部署后的日常管理 ======

# 1. 启动服务
clawdock-start

# 2. 查看日志，确认启动成功
clawdock-logs

# 3. 打开控制面板
clawdock-dashboard

# 4. 检查健康状态
clawdock-health

# ====== 场景 2：更新和重建 ======

# 1. 拉取最新代码
clawdock-pull

# 2. 重新构建镜像
clawdock-rebuild

# 3. 查看日志确认
clawdock-logs

# ====== 场景 3：故障排查 ======

# 1. 检查容器状态
clawdock-ps

# 2. 查看资源使用
clawdock-stats

# 3. 运行诊断
clawdock-doctor

# 4. 进入容器检查
clawdock-shell

# ====== 场景 4：设备管理 ======

# 1. 查看待配对设备
clawdock-devices

# 2. 批准设备配对
clawdock-approve <request-id>

# 3. 获取访问 Token
clawdock-token
```

### 开发调试工作流

```bash
# 1. 进入项目目录
clawdock-cd

# 2. 编辑配置文件
nano ~/.openclaw/config.json

# 3. 重启服务使配置生效
clawdock-restart

# 4. 查看日志验证
clawdock-logs

# 5. 进入容器测试
clawdock-shell

# 6. 在容器中运行 CLI
clawdock-cli config validate
```

---

## 故障排查

### 问题 1：命令找不到

**症状：**
```bash
clawdock-start
zsh: command not found: clawdock-start
```

**解决方案：**

```bash
# 检查脚本是否下载成功
ls -la ~/.clawdock/clawdock-helpers.sh

# 检查 shell 配置是否添加
cat ~/.zshrc | grep clawdock

# 手动加载配置
source ~/.zshrc  # 或 source ~/.bashrc

# 如果仍然失败，重新安装
rm -rf ~/.clawdock
mkdir -p ~/.clawdock
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh \
  -o ~/.clawdock/clawdock-helpers.sh
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc
source ~/.zshrc
```

---

### 问题 2：无法定位 OpenClaw 目录

**症状：**
```bash
clawdock-start
❌ OpenClaw not found in common locations.

Clone it first:

  git clone https://github.com/openclaw/openclaw.git ~/openclaw
  cd ~/openclaw && ./docker-setup.sh

Or set CLAWDOCK_DIR if it's elsewhere:

  export CLAWDOCK_DIR=/path/to/openclaw
```

**原因：**
ClawDock 在以下常见位置查找 OpenClaw 目录：
- `~/openclaw`
- 当前工作目录

如果项目在其他位置，就会出现这个错误。

**解决方案：**

**方法 1：设置 CLAWDOCK_DIR 环境变量（推荐）**

```bash
# 临时设置（仅当前会话有效）
export CLAWDOCK_DIR=/Users/aosom/Documents/yhui/github/ZYHB/openclaw
clawdock-start

# 永久设置（添加到 shell 配置）
echo 'export CLAWDOCK_DIR=/Users/aosom/Documents/yhui/github/ZYHB/openclaw' >> ~/.zshrc
source ~/.zshrc
clawdock-start
```

**方法 2：在项目目录中运行命令**

```bash
# 先进入项目目录
cd /Users/aosom/Documents/yhui/github/ZYHB/openclaw

# 然后运行 ClawDock 命令
clawdock-start
```

**方法 3：创建符号链接到常见位置**

```bash
# 创建符号链接
ln -s /Users/aosom/Documents/yhui/github/ZYHB/openclaw ~/openclaw

# ClawDock 现在可以自动找到了
clawdock-start
```

---

### 问题 3：权限错误

**症状：**
```bash
clawdock-start
Permission denied
```

**解决方案：**

```bash
# 检查脚本权限
ls -la ~/.clawdock/clawdock-helpers.sh

# 添加执行权限
chmod +x ~/.clawdock/clawdock-helpers.sh

# 检查 Docker 权限
docker ps
# 如果报错，将用户添加到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

---

### 问题 4：Docker Compose 版本不兼容

**症状：**
```bash
clawdock-start
docker compose: command not found
```

**解决方案：**

```bash
# 检查 Docker Compose 版本
docker compose version

# 如果未安装或版本过低，升级 Docker
# macOS: 升级 Docker Desktop
# Linux:
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

---

## 常见问题 (FAQ)

### Q1: ClawDock 和 deploy.sh 有什么区别？

**A:**
- **deploy.sh**：用于首次部署和重建镜像，预配置环境变量
- **ClawDock**：用于部署后的日常运维管理，简化 Docker 命令

两者是**互补关系**，推荐配合使用！

### Q2: 安装 ClawDock 会影响现有的 Docker 部署吗？

**A:** 不会。ClawDock 只是 shell 别名，不会修改任何 Docker 配置或数据。

### Q3: 可以自定义 ClawDock 命令吗？

**A:** 可以。编辑 `~/.clawdock/clawdock-helpers.sh` 文件，添加自定义别名。

### Q4: ClawDock 支持哪些 shell？

**A:** 官方支持 **zsh** 和 **bash**。其他 shell（如 fish）需要自行适配。

### Q5: 如何卸载 ClawDock？

**A:**
```bash
# 删除脚本文件
rm -rf ~/.clawdock

# 从 shell 配置中移除加载行
nano ~/.zshrc  # 或 ~/.bashrc
# 删除这一行：source ~/.clawdock/clawdock-helpers.sh

# 重新加载 shell
source ~/.zshrc
```

---

## 进阶技巧

### 技巧 1：创建自定义别名

在 `~/.clawdock/clawdock-helpers.sh` 中添加：

```bash
# 快速查看错误日志
alias clawdock-logs-error='docker compose logs --tail=100 openclaw-gateway | grep -i error'

# 快速重启并查看日志
alias clawdock-restart-logs='clawdock-restart && sleep 3 && clawdock-logs'

# 快速清理并重建
alias clawdock-reset='clawdock-clean && clawdock-start'
```

### 技巧 2：集成到其他工具

```bash
# 与 tmux 集成
alias clawdock-attach='tmux new-session -A -s openclaw "clawdock-logs"'

# 与系统服务集成
alias clawdock-enable='sudo systemctl enable docker'
alias clawdock-status='sudo systemctl status docker'
```

### 技巧 3：批量操作

```bash
# 批量更新所有 OpenClaw 实例
for dir in ~/projects/openclaw-*; do
  (cd "$dir" && clawdock-update)
done
```

---

## 相关文档

- [部署指南](./deployment-guide.md) - 完整的 Docker 部署步骤
- [配置参考](./configuration.md) - 详细的配置说明
- [故障排查](./troubleshooting.md) - 常见问题解决方案
- [官方 README](https://github.com/openclaw/openclaw/blob/main/scripts/shell-helpers/README.md) - ClawDock 官方文档

---

**最后更新：** 2026-02-27
**文档版本：** 1.0
**适用版本：** OpenClaw 2026.2.26+
