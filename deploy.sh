#!/bin/bash
# OpenClaw Docker 部署脚本
#
# 使用方法:
#   ./deploy.sh              # 使用默认配置部署
#   ./deploy.sh --no-cache   # 强制重新构建（无缓存）
#
# 配置说明: 修改下面的环境变量来定制部署

set -e  # 遇到错误立即退出

# ===============================================
# 部署配置区域 - 根据需要修改这些变量
# ===============================================

# 安装的系统包（在镜像构建时安装）
# 常用选项:
#   - 最小化: "ffmpeg"
#   - 通用: "ffmpeg git curl jq"
#   - 开发: "ffmpeg git curl jq build-essential"
#   - 完整: "ffmpeg git curl jq build-essential python3 python3-pip"
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg git curl jq"

# 额外的挂载点（将主机目录挂载到容器）
# 格式: source:target[:options]，逗号分隔，无空格
# 示例: "$HOME/Documents:/home/node/documents:rw,$HOME/.codex:/home/node/.codex:ro"
# export OPENCLAW_EXTRA_MOUNTS="$HOME/Documents:/home/node/documents:rw"

# 持久化容器主目录（使用 Docker 卷）
# 启用后，浏览器下载和工具缓存会持久化
# export OPENCLAW_HOME_VOLUME="openclaw_home"

# ===============================================
# 颜色输出辅助函数
# ===============================================

info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# ===============================================
# 预检查
# ===============================================

check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装，请先安装 Docker"
        echo "访问 https://docs.docker.com 获取安装指南"
        exit 1
    fi

    if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose 未安装，请先安装 Docker Compose v2"
        exit 1
    fi

    success "Docker 环境检查通过"
}

check_setup_script() {
    if [ ! -f "./docker-setup.sh" ]; then
        error "找不到 docker-setup.sh 脚本"
        echo "请确保你在 OpenClaw 项目根目录下运行此脚本"
        exit 1
    fi
}

# ===============================================
# 显示配置信息
# ===============================================

show_config() {
    info "部署配置信息:"
    echo "  系统包: $OPENCLAW_DOCKER_APT_PACKAGES"

    if [ -n "$OPENCLAW_EXTRA_MOUNTS" ]; then
        echo "  额外挂载: $OPENCLAW_EXTRA_MOUNTS"
    fi

    if [ -n "$OPENCLAW_HOME_VOLUME" ]; then
        echo "  持久化卷: $OPENCLAW_HOME_VOLUME"
    fi

    echo ""
}

# ===============================================
# 主执行流程
# ===============================================

main() {
    echo ""
    echo "=============================================="
    echo "  OpenClaw Docker 部署脚本"
    echo "=============================================="
    echo ""

    # 预检查
    info "步骤 1/3: 环境检查"
    check_docker
    check_setup_script
    echo ""

    # 显示配置
    info "步骤 2/3: 配置信息"
    show_config
    echo ""

    # 执行部署
    info "步骤 3/3: 开始部署"
    echo "这可能会需要几分钟时间..."
    echo ""

    # 执行官方部署脚本，传递所有参数
    if ./docker-setup.sh "$@"; then
        echo ""
        success "部署完成！"
        echo ""
        echo "后续步骤:"
        echo "  1. 访问控制面板: 使用脚本输出的 URL"
        echo "  2. 配置 AI 模型提供商（API Key）"
        echo "  3. 启用所需的消息通道（可选）"
        echo ""
        echo "常用命令:"
        echo "  - 查看日志: docker compose logs -f openclaw-gateway"
        echo "  - 重启服务: docker compose restart openclaw-gateway"
        echo "  - 停止服务: docker compose down"
        echo ""
    else
        echo ""
        error "部署失败"
        echo "请检查上方的错误信息，或查看 troubleshooting.md"
        exit 1
    fi
}

# 运行主流程
main "$@"
