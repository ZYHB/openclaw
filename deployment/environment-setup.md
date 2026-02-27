# 物理机环境设置

本文档详细说明如何在不同的 Linux 物理机环境上设置和部署 OpenClaw。

## 目录

- [Ubuntu/Debian 系统](#ubuntudebian-系统)
- [CentOS/RHEL 系统](#centosrhel-系统)
- [树莓派 (ARM64)](#树莓派-arm64)
- [NAS 设备](#nas-设备)
- [云服务器 (VPS)](#云服务器-vps)

## Ubuntu/Debian 系统

### 系统更新

```bash
# 更新包索引
sudo apt update

# 升级系统
sudo apt upgrade -y

# 安装基础工具
sudo apt install -y \
  curl \
  wget \
  git \
  build-essential \
  ca-certificates \
  gnupg \
  lsb-release
```

### Docker 安装

```bash
# 添加 Docker 官方 GPG 密钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 设置 Docker 仓库
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker compose version
```

### 用户配置

```bash
# 添加当前用户到 docker 组
sudo usermod -aG docker $USER

# 重新登录或执行
newgrp docker

# 测试免 sudo 运行
docker ps
```

### 防火墙配置

```bash
# 安装 ufw（如果未安装）
sudo apt install -y ufw

# 允许 SSH
sudo ufw allow 22/tcp

# 允许 OpenClaw 端口
sudo ufw allow 18789/tcp
sudo ufw allow 18790/tcp

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

### 性能优化

```bash
# 增加文件描述符限制
cat <<EOF | sudo tee -a /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
EOF

# 优化内核参数
cat <<EOF | sudo tee /etc/sysctl.d/99-openclaw.conf
# 网络优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Swap 使用倾向（降低以减少内存换出）
vm.swappiness = 10
EOF

# 应用内核参数
sudo sysctl -p /etc/sysctl.d/99-openclaw.conf
```

---

## CentOS/RHEL 系统

### 系统更新

```bash
# 更新系统
sudo dnf update -y

# 安装基础工具
sudo dnf install -y \
  curl \
  wget \
  git \
  gcc \
  make \
  ca-certificates
```

### Docker 安装

```bash
# 添加 Docker 仓库
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

# 安装 Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker compose version
```

### SELinux 配置

```bash
# 检查 SELinux 状态
getenforce

# 如果是 Enforcing，可以设置为 Permissive
sudo setenforce 0

# 永久禁用（不推荐，仅用于测试）
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
```

### 防火墙配置 (firewalld)

```bash
# 允许 OpenClaw 端口
sudo firewall-cmd --permanent --add-port=18789/tcp
sudo firewall-cmd --permanent --add-port=18790/tcp

# 重新加载防火墙
sudo firewall-cmd --reload

# 查看规则
sudo firewall-cmd --list-all
```

---

## 树莓派 (ARM64)

### 系统准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 设置 GPU 内存（最少 128MB）
sudo raspi-config
# 选择: Performance Options -> GPU Memory -> 128

# 启用 64 位内核（如果是 32 位系统）
# 需要重新刷入 64 位镜像
```

### Docker 安装

```bash
# 安装便捷脚本
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 添加用户到 docker 组
sudo usermod -aG docker $USER
newgrp docker

# 验证
docker --version
```

### 性能调优

```bash
# 配置交换空间（树莓派内存有限）
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# 设置: CONF_SWAPSIZE=1024

sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# 覆写频率控制（减少 SD 卡写入）
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
```

### 温度监控

```bash
# 安装温度监控工具
sudo apt install -y lm-sensors

# 查看温度
vcgencmd measure_temp

# 设置温度保护（CPU 降频温度）
echo "temp_soft=70" | sudo tee /sys/class/thermal/thermal_zone0/trip_point_0_temp
echo "temp_hard=80" | sudo tee /sys/class/thermal/thermal_zone0/trip_point_1_temp
```

---

## NAS 设备

### Synology (DSM)

#### 通过 Docker 套件安装

1. 打开套件中心，安装 "Docker" 或 "Container Manager"
2. 创建项目目录：
   ```
   /docker/openclaw
   ```
3. 上传项目文件到 NAS
4. 创建 docker-compose.yml

#### SSH 访问配置

```bash
# 启用 SSH
控制面板 → 终端机和 SNMP → 启用 SSH 功能

# SSH 连接到 NAS
ssh your-admin@nas-ip

# 切换到 root
sudo -i

# 进入 Docker 项目目录
cd /volume1/docker/openclaw
```

#### 权限配置

```bash
# 创建 OpenClaw 用户
synouser --add openclaw password "OpenClaw User" 0

# 创建数据目录
mkdir -p /volume1/docker/openclaw/data
chown -R openclaw:openclaw /volume1/docker/openclaw/data
```

#### 群辉 docker-compose.yml

```yaml
version: "3.8"
services:
  openclaw-gateway:
    image: openclaw:local
    container_name: openclaw-gateway
    environment:
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
    volumes:
      - /volume1/docker/openclaw/data:/home/node/.openclaw
    ports:
      - "18789:18789"
      - "18790:18790"
    restart: unless-stopped
```

### QNAP (QuTS hero)

```bash
# 安装 Container Station
App Center → 搜索 "Container Station" → 安装

# 通过 SSH 连接
ssh admin@nas-ip

# 创建项目目录
mkdir -p /share/Container/openclaw
cd /share/Container/openclaw
```

---

## 云服务器 (VPS)

### 常见 VPS 提供商

- **Hetzner** (德国)
- **DigitalOcean** (美国)
- **Linode** (美国)
- **Vultr** (美国)
- **AWS Lightsail** (AWS)
- **阿里云 ECS** (中国)

### 服务器选型建议

| 配置 | 适合场景 | 预估价格 |
|------|---------|---------|
| 2核/4GB | 个人使用、测试 | $5-10/月 |
| 4核/8GB | 小团队、多用户 | $20-40/月 |
| 8核/16GB | 生产环境 | $80-160/月 |

### 基础安全配置

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 创建非 root 用户
sudo adduser deploy
sudo usermod -aG sudo deploy
sudo usermod -aG docker deploy

# 配置 SSH 密钥登录
ssh-keygen -t ed25519
ssh-copy-id deploy@your-vps-ip

# 禁用密码登录（可选，增强安全）
sudo nano /etc/ssh/sshd_config
# 设置: PasswordAuthentication no
sudo systemctl restart sshd

# 配置防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 18789/tcp
sudo ufw enable
```

### fail2ban 防护

```bash
# 安装 fail2ban
sudo apt install -y fail2ban

# 创建本地配置
cat <<EOF | sudo tee /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
EOF

# 启动服务
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 自动备份

```bash
# 创建备份脚本
cat <<'EOF' > ~/backup-openclaw.sh
#!/bin/bash
BACKUP_DIR="/backup/openclaw"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# 备份配置
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C ~/.openclaw .

# 上传到远程（可选）
# rsync -avz "$BACKUP_DIR/" user@backup-server:/backups/openclaw/

# 清理 30 天前的备份
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
EOF

chmod +x ~/backup-openclaw.sh

# 添加到 crontab（每天凌晨 3 点）
crontab -e
# 添加: 0 3 * * * ~/backup-openclaw.sh
```

### 监控设置

```bash
# 安装 htop
sudo apt install -y htop

# 配置系统监控（Prometheus + Node Exporter，可选）
docker run -d \
  --name node-exporter \
  --restart always \
  -p 9100:9100 \
  prom/node-exporter
```

---

## 网络配置

### 静态 IP（Ubuntu）

```bash
# 编辑 Netplan 配置
sudo nano /etc/netplan/01-netcfg.yaml

# 内容示例：
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

# 应用配置
sudo netplan apply
```

### DNS 配置

```bash
# 编辑 DNS 配置
sudo nano /etc/systemd/resolved.conf

# 设置 DNS 服务器
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=1.0.0.1

# 重启服务
sudo systemctl restart systemd-resolved
```

---

## 故障排查工具

```bash
# 系统信息
neofetch  # 需要安装: sudo apt install neofetch

# 磁盘使用
df -h
du -sh ~/.openclaw

# 内存使用
free -h

# 进程监控
htop

# 网络连接
ss -tulnp
netstat -tulnp

# 日志查看
journalctl -u docker -f
tail -f /var/log/syslog
```

---

## 下一步

环境设置完成后：

1. 阅读 [prerequisites.md](./prerequisites.md) 确认所有要求
2. 按照 [deployment-guide.md](./deployment-guide.md) 开始部署
3. 参考 [configuration.md](./configuration.md) 进行配置

---

## 相关资源

- [Ubuntu 官方文档](https://ubuntu.com/server/docs)
- [Docker 官方文档](https://docs.docker.com)
- [Hetzner 文档](https://docs.hetzner.com)
- [Synology Docker 指南](https://kb.synology.com/en-global/DSM/tutorial/What_is_Docker)
