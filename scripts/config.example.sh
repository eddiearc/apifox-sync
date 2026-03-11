# Apifox 配置示例文件
# 复制此文件为 config.sh 并填入你的实际值
# 使用方式: source config.sh

# ============================================
# 必需配置
# ============================================

# Apifox Access Token（全局凭证）
# 获取方式: Apifox -> 个人设置 -> API 访问令牌
export APIFOX_TOKEN="apifox_your_token_here"

# ============================================
# 推荐的仓库级配置
# ============================================

# 在目标仓库内执行以下命令，将 Project ID 绑定到仓库而不是全局 shell：
#
#   git config --local apifox.project-id "4032930"
#   git config --local apifox.endpoint-folder-id "76"
#   git config --local apifox.schema-folder-id "60"
#
# 也可以在单次同步时使用 --project-id 覆盖。

# ============================================
# 可选全局默认行为
# ============================================

# 接口覆盖策略
# 可选值: deleteUnmatchedResources | merge | onlyNew
# export APIFOX_ENDPOINT_OVERWRITE="deleteUnmatchedResources"

# Schema 覆盖策略
# 可选值: KEEP_EXISTING | OVERWRITE_IF_DIFFERENT | OVERWRITE_ALWAYS
# export APIFOX_SCHEMA_OVERWRITE="KEEP_EXISTING"

# 是否更新已变更接口的文件夹位置
# export APIFOX_UPDATE_FOLDER="true"

# 是否在接口路径前添加 basePath
# export APIFOX_PREPEND_BASE_PATH="true"

# 可选：如果不想写入 git config，也可以在单次运行时显式传参：
# ./sync-to-apifox.sh --file "./openapi.json" --project-id "4032930"
