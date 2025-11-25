#!/bin/bash
# Apifox OpenAPI 同步脚本
# 用于将 OpenAPI 文档同步到 Apifox 平台
#
# 环境变量要求:
#   APIFOX_TOKEN          - Apifox Access Token (必需)
#   APIFOX_PROJECT_ID     - Apifox 项目 ID (必需)
#   APIFOX_ENDPOINT_FOLDER_ID  - 接口目标文件夹 ID (可选，默认为根目录)
#   APIFOX_SCHEMA_FOLDER_ID    - Schema 目标文件夹 ID (可选，默认为根目录)
#
# 使用方法:
#   1. 从 URL 导入:
#      ./sync-to-apifox.sh --url "https://example.com/openapi.json"
#
#   2. 从本地文件导入:
#      ./sync-to-apifox.sh --file "./openapi.json"
#
#   3. 自定义覆盖策略:
#      ./sync-to-apifox.sh --file "./openapi.json" --endpoint-overwrite MERGE_IF_NOT_EXISTS --schema-overwrite KEEP_EXISTING
#
# 覆盖策略选项:
#   endpoint-overwrite: OVERWRITE_EXISTING (默认) | MERGE_IF_NOT_EXISTS | ONLY_NEW
#   schema-overwrite: OVERWRITE_EXISTING (默认) | KEEP_EXISTING | OVERWRITE_IF_DIFFERENT

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
API_BASE_URL="https://api.apifox.com/v1"
API_VERSION="2024-03-28"
LOCALE="zh-CN"

# 默认覆盖策略
ENDPOINT_OVERWRITE_BEHAVIOR="${APIFOX_ENDPOINT_OVERWRITE:-OVERWRITE_EXISTING}"
SCHEMA_OVERWRITE_BEHAVIOR="${APIFOX_SCHEMA_OVERWRITE:-OVERWRITE_EXISTING}"
UPDATE_FOLDER="${APIFOX_UPDATE_FOLDER:-false}"
PREPEND_BASE_PATH="${APIFOX_PREPEND_BASE_PATH:-false}"

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}Apifox OpenAPI 同步脚本${NC}

${YELLOW}用法:${NC}
    $0 --url <URL>                    从 URL 导入 OpenAPI 文档
    $0 --file <FILE>                  从本地文件导入 OpenAPI 文档

${YELLOW}选项:${NC}
    --url <URL>                       OpenAPI 文档的 URL 地址
    --file <FILE>                     本地 OpenAPI 文档文件路径
    --endpoint-overwrite <STRATEGY>   接口覆盖策略 (默认: OVERWRITE_EXISTING)
                                      可选值: OVERWRITE_EXISTING | MERGE_IF_NOT_EXISTS | ONLY_NEW
    --schema-overwrite <STRATEGY>     Schema 覆盖策略 (默认: OVERWRITE_EXISTING)
                                      可选值: KEEP_EXISTING | OVERWRITE_IF_DIFFERENT | OVERWRITE_EXISTING
    --endpoint-folder <ID>            接口目标文件夹 ID
    --schema-folder <ID>              Schema 目标文件夹 ID
    --no-update-folder                不更新已变更接口的文件夹位置
    --no-prepend-base-path            不在接口路径前添加 basePath
    -h, --help                        显示此帮助信息

${YELLOW}环境变量:${NC}
    APIFOX_TOKEN                      Apifox Access Token (必需)
    APIFOX_PROJECT_ID                 Apifox 项目 ID (必需)
    APIFOX_ENDPOINT_FOLDER_ID         接口目标文件夹 ID (可选)
    APIFOX_SCHEMA_FOLDER_ID           Schema 目标文件夹 ID (可选)

${YELLOW}覆盖策略说明:${NC}
    接口覆盖策略 (endpoint-overwrite):
        - OVERWRITE_EXISTING:       覆盖已存在的接口 (默认)
        - MERGE_IF_NOT_EXISTS:      仅在不存在时添加，保留旧接口
        - ONLY_NEW:                 仅导入新接口

    Schema 覆盖策略 (schema-overwrite):
        - OVERWRITE_EXISTING:       覆盖已存在的 Schema (默认)
        - KEEP_EXISTING:            保留已存在的 Schema
        - OVERWRITE_IF_DIFFERENT:   仅在不同时覆盖

${YELLOW}示例:${NC}
    # 设置环境变量
    export APIFOX_TOKEN="apifox_xxx"
    export APIFOX_PROJECT_ID="1234567"

    # 从 URL 导入
    $0 --url "https://petstore.swagger.io/v2/swagger.json"

    # 从本地文件导入
    $0 --file "./my-api-openapi.json"

    # 使用保留策略导入
    $0 --file "./openapi.json" --endpoint-overwrite MERGE_IF_NOT_EXISTS --schema-overwrite KEEP_EXISTING

    # 指定目标文件夹
    $0 --file "./openapi.json" --endpoint-folder 76 --schema-folder 60

EOF
}

# 打印错误信息并退出
error_exit() {
    echo -e "${RED}❌ 错误: $1${NC}" >&2
    exit 1
}

# 打印警告信息
warning() {
    echo -e "${YELLOW}⚠️  警告: $1${NC}" >&2
}

# 打印成功信息
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 打印信息
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检查必需的环境变量
check_env() {
    if [ -z "$APIFOX_TOKEN" ]; then
        error_exit "未设置 APIFOX_TOKEN 环境变量。请使用: export APIFOX_TOKEN=\"your_token\""
    fi

    if [ -z "$APIFOX_PROJECT_ID" ]; then
        error_exit "未设置 APIFOX_PROJECT_ID 环境变量。请使用: export APIFOX_PROJECT_ID=\"your_project_id\""
    fi
}

# 检查必需的工具
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        error_exit "curl 未安装。请先安装 curl。"
    fi

    if ! command -v jq &> /dev/null; then
        warning "jq 未安装。将无法格式化输出 JSON。建议安装 jq: brew install jq"
    fi
}

# 执行同步
sync_to_apifox() {
    local input_type="$1"  # url 或 file
    local input_value="$2"

    info "开始同步到 Apifox..."
    echo ""

    # 构建 input 部分
    local input_string
    if [ "$input_type" = "url" ]; then
        # URL 方式：直接传递 URL
        input_string="$input_value"
        info "导入来源: URL"
        echo "  $input_value"
    else
        # 文件方式：读取文件内容并转义为 JSON 字符串
        if [ ! -f "$input_value" ]; then
            error_exit "文件不存在: $input_value"
        fi

        # 读取文件内容并转义为 JSON 字符串
        # 使用 jq 将 JSON 文件转换为转义的字符串
        if command -v jq &> /dev/null; then
            input_string=$(jq -c '.' "$input_value" | jq -Rs '.')
        else
            # 如果没有 jq，使用简单的方式（不太可靠）
            warning "未安装 jq，使用简化方式处理 JSON。建议安装 jq 以获得最佳效果。"
            input_string=$(cat "$input_value" | tr -d '\n' | sed 's/"/\\"/g')
            input_string="\"$input_string\""
        fi

        info "导入来源: 本地文件"
        echo "  $input_value"
    fi

    # 构建 options 部分
    local target_endpoint_folder="${TARGET_ENDPOINT_FOLDER_ID:-0}"
    local target_schema_folder="${TARGET_SCHEMA_FOLDER_ID:-0}"

    local options_section
    options_section=$(cat <<EOF
{
    "targetEndpointFolderId": $target_endpoint_folder,
    "targetSchemaFolderId": $target_schema_folder,
    "endpointOverwriteBehavior": "$ENDPOINT_OVERWRITE_BEHAVIOR",
    "schemaOverwriteBehavior": "$SCHEMA_OVERWRITE_BEHAVIOR",
    "updateFolderOfChangedEndpoint": $UPDATE_FOLDER,
    "prependBasePath": $PREPEND_BASE_PATH
}
EOF
)

    # 构建完整请求体
    local request_body
    request_body=$(cat <<EOF
{
    "input": $input_string,
    "options": $options_section
}
EOF
)

    echo ""
    info "同步配置:"
    echo "  项目 ID: $APIFOX_PROJECT_ID"
    echo "  接口覆盖策略: $ENDPOINT_OVERWRITE_BEHAVIOR"
    echo "  Schema 覆盖策略: $SCHEMA_OVERWRITE_BEHAVIOR"
    [ -n "$TARGET_ENDPOINT_FOLDER_ID" ] && echo "  接口目标文件夹: $TARGET_ENDPOINT_FOLDER_ID"
    [ -n "$TARGET_SCHEMA_FOLDER_ID" ] && echo "  Schema 目标文件夹: $TARGET_SCHEMA_FOLDER_ID"
    echo ""

    # 发送请求
    info "正在上传..."
    local api_url="${API_BASE_URL}/projects/${APIFOX_PROJECT_ID}/import-openapi?locale=${LOCALE}"

    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Authorization: Bearer ${APIFOX_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "X-Apifox-Api-Version: ${API_VERSION}" \
        -d "$request_body")

    # 分离响应体和状态码
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')

    echo ""

    # 检查响应状态
    case $http_code in
        200|201)
            success "同步成功！"
            echo ""

            # 尝试解析并格式化响应
            if command -v jq &> /dev/null; then
                echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            else
                echo "$response_body"
            fi

            echo ""
            info "查看文档: https://app.apifox.com/project/${APIFOX_PROJECT_ID}"
            ;;
        401)
            error_exit "认证失败 (401)。请检查 APIFOX_TOKEN 是否有效。"
            ;;
        403)
            error_exit "权限不足 (403)。请确保 Token 有项目的编辑权限。"
            ;;
        404)
            error_exit "项目不存在 (404)。请检查 APIFOX_PROJECT_ID 是否正确。"
            ;;
        400)
            error_exit "请求无效 (400)。响应内容:\n$response_body"
            ;;
        *)
            error_exit "请求失败 (HTTP $http_code)。响应内容:\n$response_body"
            ;;
    esac
}

# 解析命令行参数
INPUT_TYPE=""
INPUT_VALUE=""
TARGET_ENDPOINT_FOLDER_ID="${APIFOX_ENDPOINT_FOLDER_ID:-}"
TARGET_SCHEMA_FOLDER_ID="${APIFOX_SCHEMA_FOLDER_ID:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            INPUT_TYPE="url"
            INPUT_VALUE="$2"
            shift 2
            ;;
        --file)
            INPUT_TYPE="file"
            INPUT_VALUE="$2"
            shift 2
            ;;
        --endpoint-overwrite)
            ENDPOINT_OVERWRITE_BEHAVIOR="$2"
            shift 2
            ;;
        --schema-overwrite)
            SCHEMA_OVERWRITE_BEHAVIOR="$2"
            shift 2
            ;;
        --endpoint-folder)
            TARGET_ENDPOINT_FOLDER_ID="$2"
            shift 2
            ;;
        --schema-folder)
            TARGET_SCHEMA_FOLDER_ID="$2"
            shift 2
            ;;
        --no-update-folder)
            UPDATE_FOLDER="false"
            shift
            ;;
        --no-prepend-base-path)
            PREPEND_BASE_PATH="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error_exit "未知参数: $1\n使用 --help 查看帮助信息"
            ;;
    esac
done

# 主逻辑
main() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}   Apifox OpenAPI 同步工具${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 检查参数
    if [ -z "$INPUT_TYPE" ]; then
        error_exit "缺少必需参数。使用 --url 或 --file 指定输入源。\n使用 --help 查看帮助信息。"
    fi

    # 检查依赖和环境
    check_dependencies
    check_env

    # 执行同步
    sync_to_apifox "$INPUT_TYPE" "$INPUT_VALUE"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 运行主函数
main
