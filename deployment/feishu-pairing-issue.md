# 飞书配对问题排查记录

**日期：** 2026-02-27
**问题：** 飞书机器人反复要求配对，即使执行了 `pairing approve` 命令
**状态：** ✅ 已解决

---

## 问题现象

### 用户报告

在飞书中发送消息给机器人，收到以下回复：

```
OpenClaw: access not configured.
Your Feishu user id: ou_5aa36c275b7ee3f13772e36e5d236780
Pairing code: 2MPNZLVY
Ask the bot owner to approve with:
openclaw pairing approve feishu 2MPNZLVY
```

即使执行了批准命令：
```bash
docker compose run --rm openclaw-cli pairing approve feishu 2MPNZLVY
```

输出显示：
```
Approved feishu sender ou_5aa36c275b7ee3f13772e36e5d236780.
```

但再次发送消息，仍然收到新的配对码要求配对。

---

## 问题诊断

### 步骤 1：检查配对列表

```bash
docker compose run --rm openclaw-cli pairing list feishu
```

**输出：**
```
Pairing requests (1)
┌──────────┬───────────────────────────────────────┬───────────────────────────────────────┬──────────────────────────┐
│ Code     │ feishuUserId                          │ Meta                                  │ Requested                │
├──────────┼───────────────────────────────────────┼───────────────────────────────────────┼──────────────────────────┤
│ A6WEV5R9 │ ou_5aa36c275b7ee3f13772e36e5d236780   │ {"name":"张三","accountId":"default"}  │ 2026-02-27T11:21:19.599Z │
└──────────┴───────────────────────────────────────┴───────────────────────────────────────┴──────────────────────────┘
```

**发现：** 配对请求仍在列表中，说明之前的 `approve` 命令没有真正保存配对信息。

### 步骤 2：检查配置文件

```bash
cat ~/.openclaw/openclaw.json | grep -A 15 '"channels"'
```

**原始配置：**
```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_a1b2c3d4e5f6g7h8",
      "appSecret": "your_app_secret_here",
      "domain": "feishu",
      "groupPolicy": "allowlist",
      "groupAllowFrom": [
        "oc_your_group_id_1",
        "oc_your_group_id_2"
      ],
      "dmPolicy": "allowlist"
    }
  }
}
```

**🔍 根本原因发现：**

1. **`dmPolicy` 设置为 `"allowlist"`** - 白名单模式
2. **缺少 `allowFrom` 字段** - 没有定义允许的用户列表
3. 在 allowlist 模式下，如果缺少 `allowFrom`，所有用户（包括已配对的）都会被拒绝

---

## 解决方案

### 方法 1：切换到 pairing 模式（推荐）

将 `dmPolicy` 从 `"allowlist"` 改为 `"pairing"`，并添加 `allowFrom` 字段：

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_a1b2c3d4e5f6g7h8",
      "appSecret": "your_app_secret_here",
      "domain": "feishu",
      "groupPolicy": "allowlist",
      "groupAllowFrom": [
        "oc_your_group_id_1",
        "oc_your_group_id_2"
      ],
      "dmPolicy": "pairing",
      "allowFrom": [
        "ou_your_user_id_here"
      ]
    }
  }
}
```

**修改说明：**
- `dmPolicy: "pairing"` - 启用配对模式（新用户需要配对，已配对用户可直接访问）
- `allowFrom` - 明确添加已批准的用户 ID

### 方法 2：保持在 allowlist 模式

如果不想使用配对模式，可以直接使用 allowlist 并添加用户：

```json
{
  "channels": {
    "feishu": {
      "dmPolicy": "allowlist",
      "allowFrom": [
        "ou_5aa36c275b7ee3f13772e36e5d236780"
      ]
    }
  }
}
```

**区别：**
- `allowlist` - 只有列表中的用户可以访问，无需配对
- `pairing` - 用户需要先配对，配对后的用户会被添加到允许列表

---

## 执行步骤

### 1. 编辑配置文件

```bash
nano ~/.openclaw/openclaw.json
```

### 2. 修改 feishu 配置部分

找到 `"channels": { "feishu": { ... } }` 部分，进行上述修改。

### 3. 保存并重启 Gateway

```bash
# 配置会自动热重载（推荐方式）
# 或手动重启
docker compose restart openclaw-gateway
```

### 4. 验证配置生效

查看 Gateway 日志：
```bash
docker compose logs --tail=50 openclaw-gateway | grep -E "reload|feishu"
```

**期望输出：**
```
[reload] config hot reload applied (channels.feishu.dmPolicy, channels.feishu.allowFrom)
[feishu] starting feishu[default] (mode: websocket)
[feishu] feishu[default]: WebSocket client started
```

---

## 验证修复

在飞书中发送测试消息：

```
你好
```

**预期结果：** 机器人正常回复，不再要求配对。

---

## DM 策略说明

### 可用的 dmPolicy 值

| 值 | 行为 | 适用场景 |
|-----|------|---------|
| `"pairing"` | **推荐**。陌生人收到配对码，批准后可访问 | 大多数场景 |
| `"allowlist"` | 只有 `allowFrom` 列表中的用户可访问 | 完全控制访问权限 |
| `"open"` | 所有人可直接访问（需 `allowFrom: ["*"]`） | 公开机器人 |
| `"disabled"` | 禁用私信 | 仅群聊使用 |

### 配对模式 vs 白名单模式

#### 配对模式（pairing）

**优点：**
- ✅ 灵活性高，可以逐个批准用户
- ✅ 用户首次访问时自动触发配对流程
- ✅ 配对信息持久化保存

**工作流程：**
1. 陌生人发送消息 → 收到配对码
2. 管理员执行 `pairing approve feishu <CODE>`
3. 用户可以正常对话

#### 白名单模式（allowlist）

**优点：**
- ✅ 更严格的安全控制
- ✅ 无需配对流程
- ✅ 适合已知用户群体

**注意事项：**
- ⚠️ 必须设置 `allowFrom` 字段
- ⚠️ 列表外的用户无法访问（不会收到配对码）

---

## 常见错误

### 错误 1：allowlist 模式缺少 allowFrom

**症状：**
```
OpenClaw: access not configured.
```

**原因：**
```json
{
  "channels": {
    "feishu": {
      "dmPolicy": "allowlist"
      // ❌ 缺少 allowFrom
    }
  }
}
```

**解决：**
添加 `allowFrom` 字段，或改用 `pairing` 模式。

### 错误 2：pairing approve 成功但仍要求配对

**症状：**
执行 `pairing approve` 后显示成功，但仍然收到配对要求。

**原因：**
- `dmPolicy` 设置为 `allowlist`
- 配对批准没有写入 `allowFrom`

**解决：**
检查 `dmPolicy` 设置，确保使用 `pairing` 模式。

### 错误 3：配置修改后未生效

**原因：**
- Gateway 未重启
- 配置文件语法错误

**解决：**
```bash
# 重启 Gateway
docker compose restart openclaw-gateway

# 检查配置语法
docker compose run --rm openclaw-cli config validate

# 查看日志
docker compose logs -f openclaw-gateway
```

---

## 添加新用户

### 配对模式（自动）

新用户直接发送消息给机器人，会收到配对码，管理员批准即可。

### 白名单模式（手动）

编辑配置文件添加用户 ID：

```json
{
  "channels": {
    "feishu": {
      "dmPolicy": "allowlist",
      "allowFrom": [
        "ou_5aa36c275b7ee3f13772e36e5d236780",
        "ou_new_user_id_here"  // 添加新用户
      ]
    }
  }
}
```

重启 Gateway：
```bash
docker compose restart openclaw-gateway
```

---

## 查看已批准用户

### 配对模式

```bash
docker compose run --rm openclaw-cli pairing list feishu
```

### 白名单模式

```bash
cat ~/.openclaw/openclaw.json | grep -A 10 'allowFrom'
```

---

## 撤销用户访问权限

### 从白名单移除

```bash
nano ~/.openclaw/openclaw.json
```

从 `allowFrom` 数组中删除用户 ID，然后重启 Gateway。

### 配对模式撤销

OpenClaw 目前不提供直接撤销配对的命令，建议：
1. 切换到 allowlist 模式
2. 或编辑配置文件手动管理

---

## 相关文档

- [飞书配置指南](./feishu-setup.md)
- [配置参考](./configuration.md)
- [故障排查](./troubleshooting.md)

---

**总结：**

本次问题的根本原因是 `dmPolicy` 设置为 `allowlist` 但缺少必需的 `allowFrom` 字段。解决方案是切换到 `pairing` 模式并添加 `allowFrom` 配置，或者正确配置 allowlist 模式的 `allowFrom` 字段。

**推荐使用 `pairing` 模式**，因为它提供了更好的灵活性和用户体验。
