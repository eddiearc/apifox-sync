# Apifox 配置示例文件
# 复制此文件为 config.sh 并填入你的实际值
# 使用方式: source config.sh

# ============================================
# 必需配置
# ============================================

# Apifox Access Token
# 获取方式: Apifox -> 个人设置 -> API 访问令牌
export APIFOX_TOKEN="apifox_your_token_here"

# Apifox 项目 ID
# 从项目 URL 获取，例如: https://app.apifox.com/project/1234567
export APIFOX_PROJECT_ID="your_project_id"

# ============================================
# 可选配置
# ============================================

# 接口目标文件夹 ID (不设置则导入到根目录)
# export APIFOX_ENDPOINT_FOLDER_ID="76"

# Schema 目标文件夹 ID (不设置则导入到根目录)
# export APIFOX_SCHEMA_FOLDER_ID="60"

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

# ============================================
# 使用示例
# ============================================

# 1. 复制并编辑配置文件:
#    cp config.example.sh config.sh
#    vim config.sh  # 填入实际值
#
# 2. 加载配置:
#    source config.sh
#
# 3. 运行同步:
#    ./sync-to-apifox.sh --file "./openapi.json"
