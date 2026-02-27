# 飞书（Feishu/Lark）配置指南

本指南介绍如何在 Docker 部署的 OpenClaw 中配置飞书消息通道。

## 目录

- [前置要求](#前置要求)
- [步骤 1：安装飞书插件](#步骤-1安装飞书插件)
- [步骤 2：创建飞书应用](#步骤-2创建飞书应用)
- [步骤 3：配置应用权限](#步骤-3配置应用权限)
- [步骤 4：启用机器人能力](#步骤-4启用机器人能力)
- [步骤 5：配置事件订阅](#步骤-5配置事件订阅)
- [步骤 6：发布应用](#步骤-6发布应用)
- [步骤 7：配置 OpenClaw](#步骤-7配置-openclaw)
- [步骤 8：测试连接](#步骤-8测试连接)
- [常见问题](#常见问题)

---

## 前置要求

- ✅ 已完成 OpenClaw Docker 部署
- ✅ 飞书企业账号（可免费注册）
- ✅ Gateway 服务正在运行

---

## 步骤 1：安装飞书插件

飞书是作为插件提供的，需要先安装：

```bash
# 使用 Docker Compose 运行 CLI 安装插件
docker compose run --rm openclaw-cli plugins install @openclaw/feishu
```

**本地开发版本**（从 git 仓库运行）：

```bash
docker compose run --rm openclaw-cli plugins install ./extensions/feishu
```

---

## 步骤 2：创建飞书应用

### 2.1 打开飞书开放平台

1. 访问 [飞书开放平台](https://open.feishu.cn/app) 并登录
2. **国际版（Lark）用户**：访问 [https://open.larksuite.com/app](https://open.larksuite.com/app)

### 2.2 创建企业自建应用

1. 点击 **"创建企业自建应用"**
2. 填写应用信息：
   - **应用名称**：例如 "OpenClaw AI 助手"
   - **应用描述**：例如 "AI 助手机器人"
   - **应用图标**：选择一个图标
3. 点击 **"创建"**

![创建应用示例](../docs/images/feishu-step2-create-app.png)

### 2.3 复制凭证

在 **"凭证与基础信息"** 页面，复制并保存以下信息：

- **App ID**：格式如 `cli_a1b2c3d4e5f6g7h8`
- **App Secret**：点击查看并复制

⚠️ **重要**：App Secret 必须保密，不要泄露！

![获取凭证](../docs/images/feishu-step3-credentials.png)

---

## 步骤 3：配置应用权限

在 **"权限管理"** 页面：

### 3.1 批量导入权限

1. 点击 **"批量导入权限"**
2. 选择 **"按 JSON 导入"**
3. 粘贴以下权限配置：

```json
{
  "scopes": {
    "tenant": [
      "aily:file:read",
      "aily:file:write",
      "application:application.app_message_stats.overview:readonly",
      "application:application.self_manage",
      "application:bot.menu:write",
      "contact:user.employee_id:readonly",
      "corehr:file:download",
      "event:ip_list",
      "im:chat.access_event.bot_p2p_chat:read",
      "im:chat.members:bot_access",
      "im:message",
      "im:message.group_at_msg:readonly",
      "im:message.p2p_msg:readonly",
      "im:message:readonly",
      "im:message:send_as_bot",
      "im:resource"
    ],
    "user": [
      "aily:file:read",
      "aily:file:write",
      "im:chat.access_event.bot_p2p_chat:read"
    ]
  }
}
```

4. 点击 **"确定"** 导入

![配置权限](../docs/images/feishu-step4-permissions.png)

---

## 步骤 4：启用机器人能力

在 **"能力管理"** > **"机器人"** 页面：

1. 开启 **"机器人能力"** 开关
2. 设置机器人名称（例如 "AI 助手"）
3. 可选：上传机器人头像
4. 点击 **"保存"**

![启用机器人](../docs/images/feishu-step5-bot-capability.png)

---

## 步骤 5：配置事件订阅

⚠️ **重要顺序**：配置事件订阅前，必须先完成以下步骤：

1. ✅ 已运行 `docker compose run --rm openclaw-cli channels add` 添加飞书通道
2. ✅ Gateway 服务正在运行：`docker compose ps`

### 配置步骤

在 **"事件订阅"** 页面：

1. **选择订阅方式**：选择 **"通过长连接接收事件"**（WebSocket）
2. **添加事件**：点击 **"添加事件"**，选择 `im.message.receive_v1`
3. **保存**：点击 **"保存"**

⚠️ 如果 Gateway 未运行，长连接配置可能无法保存！

![配置事件订阅](../docs/images/feishu-step6-event-subscription.png)

---

## 步骤 6：发布应用

1. 进入 **"版本管理与发布"**
2. 点击 **"创建版本"**
3. 填写版本信息（版本号、更新日志）
4. 点击 **"提交审核"**
5. 等待管理员审批（企业自建应用通常会自动通过）

---

## 步骤 7：配置 OpenClaw

### 方法 1：使用向导配置（推荐）

```bash
# 运行通道添加向导
docker compose run --rm openclaw-cli channels add
```

1. 选择 **"Feishu"**
2. 输入 **App ID**：`cli_a1b2c3d4e5f6g7h8`
3. 输入 **App Secret**：`your_app_secret_here`
4. 确认配置

### 方法 2：编辑配置文件

编辑 `~/.openclaw/config.json`：

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "dmPolicy": "pairing",
      "accounts": {
        "main": {
          "appId": "cli_a1b2c3d4e5f6g7h8",
          "appSecret": "your_app_secret_here",
          "botName": "My AI assistant"
        }
      }
    }
  }
}
```

配置完成后重启 Gateway：

```bash
docker compose restart openclaw-gateway
```

### 方法 3：使用环境变量

```bash
# 在 docker-compose.yml 中添加环境变量
services:
  openclaw-gateway:
    environment:
      FEISHU_APP_ID: "cli_a1b2c3d4e5f6g7h8"
      FEISHU_APP_SECRET: "your_app_secret_here"
```

### Lark（国际版）域名配置

如果使用 Lark 国际版，需要设置域名：

```json
{
  "channels": {
    "feishu": {
      "domain": "lark",
      "accounts": {
        "main": {
          "appId": "cli_a1b2c3d4e5f6g7h8",
          "appSecret": "your_app_secret_here"
        }
      }
    }
  }
}
```

---

## 步骤 8：测试连接

### 8.1 检查 Gateway 状态

```bash
# 检查容器状态
docker compose ps

# 查看日志
docker compose logs -f openclaw-gateway

# 使用 CLI 检查状态
docker compose run --rm openclaw-cli gateway status
```

### 8.2 发送测试消息

1. 在飞书中搜索你的机器人
2. 发送消息：`你好`
3. 机器人应该回复配对码

### 8.3 批准配对

默认情况下，机器人会返回配对码。需要批准后才能正常对话：

```bash
# 查看待批准的配对请求
docker compose run --rm openclaw-cli pairing list feishu

# 输出示例：
# Pending pairings:
#   - Code: ABC123
#     User: 张三
#     Time: 2026-02-27 10:30:00

# 批准配对
docker compose run --rm openclaw-cli pairing approve feishu ABC123
```

配对成功后，就可以正常对话了！

---

## 常见问题

### Q1: 机器人在群聊中不回复

**可能原因：**
1. 机器人未添加到群聊
2. 没有 @mention 机器人（默认需要 @）
3. `groupPolicy` 设置为 `"disabled"`

**解决方案：**

```bash
# 1. 确认机器人已在群聊中
# 在飞书群成员列表中查找机器人

# 2. @mention 机器人后发送消息

# 3. 检查日志
docker compose logs -f openclaw-gateway | grep feishu
```

### Q2: 机器人收不到消息

**检查清单：**

```bash
# 1. 应用是否已发布
# 在飞书开放平台确认应用状态

# 2. 事件订阅是否正确
# 确认已添加 im.message.receive_v1 事件
# 确认选择了"长连接"方式

# 3. 权限是否完整
# 在"权限管理"页面检查所有权限已导入

# 4. Gateway 是否运行
docker compose ps

# 5. 查看详细日志
docker compose logs --tail=100 openclaw-gateway
```

### Q3: App Secret 泄露了怎么办

**立即处理：**

1. 在飞书开放平台重置 App Secret
2. 更新配置文件中的 App Secret
3. 重启 Gateway

```bash
# 编辑配置
nano ~/.openclaw/config.json

# 更新 appSecret 后重启
docker compose restart openclaw-gateway
```

### Q4: 配对码已过期

配对码有有效期限制。如果过期：

1. 重新发送消息给机器人
2. 使用新的配对码批准

```bash
docker compose run --rm openclaw-cli pairing approve feishu <NEW_CODE>
```

### Q5: 如何获取群组 ID 和用户 ID

**获取群组 ID（chat_id）**

群组 ID 格式：`oc_xxxxxxxxxxxxxxxxx`

```bash
# 方法 1：从日志中查找（推荐）
# 1. 在群聊中 @mention 机器人
# 2. 查看日志
docker compose logs -f openclaw-gateway | grep "chat_id"

# 方法 2：使用飞书 API 调试工具
# 访问飞书开放平台的 API 调试工具
```

**获取用户 ID（open_id）**

用户 ID 格式：`ou_xxxxxxxxxxxxxxxxx`

```bash
# 方法 1：从配对请求中查看
docker compose run --rm openclaw-cli pairing list feishu

# 方法 2：从日志中查找
# 给机器人发消息，查看日志
docker compose logs -f openclaw-gateway | grep "open_id"
```

### Q6: Docker 环境中插件安装失败

```bash
# 检查网络连接
docker compose run --rm openclaw-cli curl -I https://registry.npmjs.org

# 尝试重新安装
docker compose run --rm openclaw-cli plugins install @openclaw/feishu

# 查看详细错误日志
docker compose run --rm openclaw-cli plugins install @openclaw/feishu --verbose
```

---

## 高级配置

### 群聊策略配置

#### 允许所有群聊，需要 @mention（默认）

```json
{
  "channels": {
    "feishu": {
      "groupPolicy": "open"
    }
  }
}
```

#### 允许所有群聊，不需要 @mention

```json
{
  "channels": {
    "feishu": {
      "groupPolicy": "open",
      "groups": {
        "oc_xxx": {
          "requireMention": false
        }
      }
    }
  }
}
```

#### 仅允许特定用户在群聊中使用

```json
{
  "channels": {
    "feishu": {
      "groupPolicy": "allowlist",
      "groupAllowFrom": ["ou_xxx", "ou_yyy"]
    }
  }
}
```

### 私信策略配置

#### 配对模式（默认，推荐）

```json
{
  "channels": {
    "feishu": {
      "dmPolicy": "pairing"
    }
  }
}
```

#### 白名单模式

```json
{
  "channels": {
    "feishu": {
      "dmPolicy": "allowlist",
      "allowFrom": ["ou_xxx", "ou_yyy"]
    }
  }
}
```

#### 开放模式（不推荐）

```json
{
  "channels": {
    "feishu": {
      "dmPolicy": "open",
      "allowFrom": ["*"]
    }
  }
}
```

### 多账号配置

```json
{
  "channels": {
    "feishu": {
      "accounts": {
        "main": {
          "appId": "cli_xxx",
          "appSecret": "xxx",
          "botName": "主机器人"
        },
        "backup": {
          "appId": "cli_yyy",
          "appSecret": "yyy",
          "botName": "备用机器人",
          "enabled": false
        }
      }
    }
  }
}
```

### 消息限制配置

```json
{
  "channels": {
    "feishu": {
      "textChunkLimit": 2000,
      "mediaMaxMb": 30
    }
  }
}
```

### 流式输出配置

飞书支持通过交互卡片实现流式输出：

```json
{
  "channels": {
    "feishu": {
      "streaming": true,
      "blockStreaming": true
    }
  }
}
```

---

## Docker 常用命令

```bash
# 查看飞书相关日志
docker compose logs -f openclaw-gateway | grep -i feishu

# 重启 Gateway
docker compose restart openclaw-gateway

# 进入容器调试
docker compose exec openclaw-gateway bash

# 查看配置文件
docker compose exec openclaw-gateway cat /home/node/.openclaw/config.json

# 运行飞书相关命令
docker compose run --rm openclaw-cli pairing list feishu
docker compose run --rm openclaw-cli pairing approve feishu <CODE>
docker compose run --rm openclaw-cli channels status
```

---

## 相关文档

- [官方飞书文档](../docs/channels/feishu.md)
- [部署指南](./deployment-guide.md)
- [配置参考](./configuration.md)
- [故障排查](./troubleshooting.md)

---

**最后更新：** 2026-02-27
**文档版本：** 1.0
**适用版本：** OpenClaw 2026.2.26+
