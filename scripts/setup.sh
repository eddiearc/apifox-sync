#!/bin/bash
# Apifox 快速设置脚本
# 用于初次配置 Apifox 同步工具

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Apifox 同步工具 - 快速设置${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 全局配置只保存 Token；项目绑定保存到当前仓库的 git local config。
CONFIG_FILE="$HOME/.apifox/config.sh"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)

if [ -z "$REPO_ROOT" ]; then
    echo -e "${RED}❌ 当前目录不在 git 仓库内。请切到目标仓库后再运行 setup.sh。${NC}"
    echo "推荐配置方式:"
    echo "  1. 在仓库目录运行本脚本"
    echo "  2. 或手动执行: git config --local apifox.project-id <project_id>"
    exit 1
fi

echo -e "${GREEN}让我们开始配置 Apifox 同步工具${NC}"
echo -e "${BLUE}当前仓库:${NC} $REPO_ROOT"
echo ""

# ============================================
# 1. 获取 Access Token
# ============================================
echo -e "${BLUE}步骤 1: 配置全局 Apifox Access Token${NC}"
echo "Token 是用户级凭证，建议全局配置；Project ID 是仓库级绑定，会在下一步写入当前仓库。"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  检测到已存在全局 Token 配置: $CONFIG_FILE${NC}"
    read -p "是否继续复用现有 Token 配置? (Y/n): " reuse_token
    if [[ ! $reuse_token =~ ^[Nn]$ ]]; then
        apifox_token=""
        echo -e "${GREEN}将保留现有 Token 配置${NC}"
    fi
fi

if [ -z "${apifox_token+x}" ]; then
    echo "请按以下步骤获取 Token:"
    echo "  1. 登录 Apifox (https://app.apifox.com)"
    echo "  2. 点击右上角头像 -> 个人设置"
    echo "  3. 进入「API 访问令牌」页面"
    echo "  4. 点击「生成新令牌」"
    echo "  5. 复制生成的 Token"
    echo ""
    read -p "请输入你的 Apifox Token: " apifox_token

    if [ -z "$apifox_token" ]; then
        echo -e "${RED}❌ Token 不能为空${NC}"
        exit 1
    fi
fi

# ============================================
# 2. 获取 Project ID
# ============================================
echo ""
echo -e "${BLUE}步骤 2: 绑定当前仓库的 Apifox 项目 ID${NC}"
echo "这个 Project ID 将写入当前仓库的 git local config，不再依赖全局环境变量。"
echo "请按以下步骤获取 Project ID:"
echo "  1. 在 Apifox 中打开你的项目"
echo "  2. 从浏览器地址栏复制项目 ID"
echo "     例如: https://app.apifox.com/project/1234567"
echo "     则 Project ID 为: 1234567"
echo ""
read -p "请输入你的 Project ID: " project_id

if [ -z "$project_id" ]; then
    echo -e "${RED}❌ Project ID 不能为空${NC}"
    exit 1
fi

# ============================================
# 3. 可选配置
# ============================================
echo ""
echo -e "${BLUE}步骤 3: 当前仓库的可选配置 (直接回车跳过)${NC}"
echo ""

read -p "接口目标文件夹 ID (可选): " endpoint_folder_id
read -p "Schema 目标文件夹 ID (可选): " schema_folder_id

# ============================================
# 4. 保存配置
# ============================================
echo ""
echo -e "${BLUE}步骤 4: 保存全局 Token + 仓库绑定${NC}"

if [ -n "${apifox_token:-}" ]; then
    mkdir -p "$HOME/.apifox"
    cat > "$CONFIG_FILE" <<EOF
# Apifox 全局凭证配置
# 由快速设置脚本自动生成于 $(date)

export APIFOX_TOKEN="$apifox_token"

# 可选全局默认行为
export APIFOX_ENDPOINT_OVERWRITE="deleteUnmatchedResources"
export APIFOX_SCHEMA_OVERWRITE="KEEP_EXISTING"
export APIFOX_UPDATE_FOLDER="true"
export APIFOX_PREPEND_BASE_PATH="true"
EOF
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✅ 全局 Token 已保存到: $CONFIG_FILE${NC}"
fi

git -C "$REPO_ROOT" config --local apifox.project-id "$project_id"

if [ -n "$endpoint_folder_id" ]; then
    git -C "$REPO_ROOT" config --local apifox.endpoint-folder-id "$endpoint_folder_id"
else
    git -C "$REPO_ROOT" config --local --unset apifox.endpoint-folder-id 2>/dev/null || true
fi

if [ -n "$schema_folder_id" ]; then
    git -C "$REPO_ROOT" config --local apifox.schema-folder-id "$schema_folder_id"
else
    git -C "$REPO_ROOT" config --local --unset apifox.schema-folder-id 2>/dev/null || true
fi

echo -e "${GREEN}✅ 当前仓库的 Apifox 绑定已写入 git local config${NC}"
echo "   git config --local apifox.project-id $project_id"
echo ""

# ============================================
# 5. 测试连接
# ============================================
echo -e "${BLUE}步骤 5: 测试连接${NC}"
echo "正在测试 Apifox API 连接..."

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# 测试 API 连接
response=$(curl -s -w "\n%{http_code}" \
    -X GET "https://api.apifox.com/v1/projects/${project_id}" \
    -H "Authorization: Bearer ${APIFOX_TOKEN:-$apifox_token}" \
    -H "X-Apifox-Api-Version: 2024-03-28")

http_code=$(echo "$response" | tail -n1)

echo ""
if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✅ 连接成功！配置正确。${NC}"
else
    echo -e "${YELLOW}⚠️  连接测试返回状态码: $http_code${NC}"
    echo "这可能表示配置有问题，但不一定影响使用。"
    echo "请在实际使用时检查是否正常工作。"
fi

# ============================================
# 6. 完成
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 设置完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "接下来的使用步骤:"
echo ""
echo "1. 在 shell 会话中加载全局 Token 配置:"
echo -e "   ${YELLOW}source $CONFIG_FILE${NC}"
echo ""
echo "2. 确认当前仓库绑定:"
echo -e "   ${YELLOW}git config --local --get-regexp '^apifox\\.'${NC}"
echo ""
echo "3. 从本地文件同步:"
echo -e "   ${YELLOW}./sync-to-apifox.sh --file \"./openapi.json\"${NC}"
echo ""
echo "4. 从 URL 同步:"
echo -e "   ${YELLOW}./sync-to-apifox.sh --url \"https://example.com/openapi.json\"${NC}"
echo ""
echo "5. 查看帮助信息:"
echo -e "   ${YELLOW}./sync-to-apifox.sh --help${NC}"
echo ""
echo "6. 查看完整文档:"
echo -e "   ${YELLOW}cat README.md${NC}"
echo ""

# 可选：询问是否添加到 shell 配置
echo ""
read -p "是否要将全局 Token 配置自动加载到你的 shell? (y/N): " auto_load

if [[ $auto_load =~ ^[Yy]$ ]]; then
    SHELL_CONFIG=""

    if [ -n "$BASH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    fi

    if [ -n "$SHELL_CONFIG" ]; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Apifox Token 配置自动加载" >> "$SHELL_CONFIG"
        echo "[ -f $CONFIG_FILE ] && source $CONFIG_FILE" >> "$SHELL_CONFIG"
        echo ""
        echo -e "${GREEN}✅ 已添加到 $SHELL_CONFIG${NC}"
        echo "重新启动 shell 或运行以下命令生效:"
        echo -e "   ${YELLOW}source $SHELL_CONFIG${NC}"
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
