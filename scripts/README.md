# Apifox Sync Scripts

Apifox 同步工具脚本集合，用于自动化 API 文档的提取和同步。

## 脚本列表

### sync-to-apifox.sh

核心同步脚本，用于将 OpenAPI 文档上传到 Apifox 平台。

### setup.sh

交互式配置向导，帮助你快速设置 Apifox 凭证。

---

## sync-to-apifox.sh - 详细说明

#### 配置方式

推荐采用“两层配置”：

1. 全局环境变量只保存 `APIFOX_TOKEN`
2. 当前仓库通过 `git config --local apifox.project-id` 绑定目标 Apifox 项目

```bash
# 全局 Token
export APIFOX_TOKEN="apifox_xxx"

# 在目标仓库内执行
git config --local apifox.project-id "4032930"
git config --local apifox.endpoint-folder-id "76"
git config --local apifox.schema-folder-id "60"
```

脚本按以下顺序解析目标项目：

1. `--project-id`
2. 当前仓库的 `git config --local apifox.project-id`
3. `APIFOX_PROJECT_ID` 兼容兜底

兼容环境变量如下：

```bash
# 必需的环境变量
export APIFOX_TOKEN="apifox_xxx"          # 从 Apifox 获取的 Access Token

# 兼容兜底，不推荐长期使用
export APIFOX_PROJECT_ID="1234567"        # Apifox 项目 ID
export APIFOX_ENDPOINT_FOLDER_ID="76"     # 接口目标文件夹 ID
export APIFOX_SCHEMA_FOLDER_ID="60"       # Schema 目标文件夹 ID
export APIFOX_ENDPOINT_OVERWRITE="OVERWRITE_EXISTING"  # 接口覆盖策略
export APIFOX_SCHEMA_OVERWRITE="KEEP_EXISTING"  # Schema 覆盖策略
```

#### 获取凭证

##### 获取 Access Token

1. 登录 Apifox
2. 进入「个人设置」→「API 访问令牌」
3. 点击「生成新令牌」
4. 复制生成的 Token

##### 获取 Project ID

从项目 URL 中获取，例如：
- URL: `https://app.apifox.com/project/1234567`
- Project ID: `1234567`

#### 使用方法

##### 从 URL 导入

```bash
./sync-to-apifox.sh --url "https://petstore.swagger.io/v2/swagger.json"
```

##### 从本地文件导入

```bash
./sync-to-apifox.sh --file "./my-api-openapi.json"
```

##### 查看解析后的配置

```bash
./sync-to-apifox.sh --print-config
```

##### 使用自定义覆盖策略

```bash
# 保留策略：仅在不存在时添加，不覆盖已有接口
./sync-to-apifox.sh --file "./openapi.json" \
  --endpoint-overwrite MERGE_IF_NOT_EXISTS \
  --schema-overwrite KEEP_EXISTING
```

##### 指定目标文件夹

```bash
./sync-to-apifox.sh --file "./openapi.json" \
  --endpoint-folder 76 \
  --schema-folder 60
```

#### 覆盖策略说明

**接口覆盖策略 (endpoint-overwrite)**:
- `OVERWRITE_EXISTING` (默认): 覆盖已存在的接口
- `MERGE_IF_NOT_EXISTS`: 仅在不存在时添加，保留旧接口
- `ONLY_NEW`: 仅导入新接口，不更新已存在的接口

**Schema 覆盖策略 (schema-overwrite)**:
- `KEEP_EXISTING` (默认): 保留已存在的 Schema
- `OVERWRITE_IF_DIFFERENT`: 仅在不同时覆盖
- `OVERWRITE_ALWAYS`: 总是覆盖

#### 完整示例

```bash
#!/bin/bash

# 1. 设置全局 Token
export APIFOX_TOKEN="apifox_xxxxxxxxxxxxxx"

# 2. 在当前仓库绑定 Apifox 项目
git config --local apifox.project-id "1234567"

# 3. 从本地文件同步（完全同步模式）
./sync-to-apifox.sh --file "./openapi.json"

# 4. 从 URL 同步（保留模式）
./sync-to-apifox.sh \
  --url "https://example.com/openapi.json" \
  --endpoint-overwrite MERGE_IF_NOT_EXISTS \
  --schema-overwrite KEEP_EXISTING

# 5. 同步到指定文件夹
./sync-to-apifox.sh \
  --file "./openapi.json" \
  --endpoint-folder 76 \
  --schema-folder 60 \
  --endpoint-overwrite MERGE_IF_NOT_EXISTS
```

## 典型工作流

### 从 Swagger/OpenAPI URL 同步

```bash
# 直接从 URL 同步到 Apifox
export APIFOX_TOKEN="your_token"
git config --local apifox.project-id "your_project_id"

./sync-to-apifox.sh --url "https://your-api.com/swagger.json"
```

### 从 Claude 生成的文档同步

```bash
# 1. 让 Claude 从代码中提取并生成 OpenAPI 文档
# (通过 Claude Code 交互完成，Claude 会读取 handler 文件并生成 OpenAPI JSON)

# 2. 同步生成的文档到 Apifox
export APIFOX_TOKEN="your_token"
git config --local apifox.project-id "your_project_id"
./sync-to-apifox.sh --file "./generated-openapi.json"
```

## 配置文件方式

全局 Token 可以放在配置文件，但 project-id 仍然建议绑定到仓库：

```bash
# ~/.apifox/config.sh
export APIFOX_TOKEN="apifox_xxx"
```

使用时 source 配置文件：

```bash
source ~/.apifox/config.sh
git config --local apifox.project-id "1234567"
./sync-to-apifox.sh --file "./openapi.json"
```

## 错误排查

### 401 Unauthorized
- **原因**: Token 无效或过期
- **解决**: 重新生成 Access Token

### 404 Not Found
- **原因**: 项目 ID 错误，或当前仓库绑定错了项目
- **解决**: 运行 `./sync-to-apifox.sh --print-config` 检查解析结果

### 400 Bad Request
- **原因**: OpenAPI 格式错误
- **解决**: 验证 OpenAPI 文档的 JSON 格式

### 403 Forbidden
- **原因**: Token 没有项目编辑权限
- **解决**: 确保 Token 有相应权限

## 注意事项

1. **Token 安全**: 不要将 Token 提交到版本控制系统
2. **项目隔离**: 不要把 `APIFOX_PROJECT_ID` 长期放在全局环境变量里，优先使用仓库级 git config
3. **覆盖策略**: 默认使用 `OVERWRITE_EXISTING` 会覆盖已有接口，可使用 `MERGE_IF_NOT_EXISTS` 保留现有接口
4. **API 版本**: 脚本使用 Apifox API v1，版本号为 2024-03-28
5. **OpenAPI 版本**: 推荐使用 OpenAPI 3.0.0 格式，兼容性最好

## 依赖要求

- `curl`: HTTP 请求工具（必需）
- `jq`: JSON 处理工具（可选，用于格式化输出）

安装 jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

## 参考文档

- [Apifox OpenAPI 官方文档](https://apifox-openapi.apifox.cn/api-173409873)
- [OpenAPI 3.0 规范](https://swagger.io/specification/)
