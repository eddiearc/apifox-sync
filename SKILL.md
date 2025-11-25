---
name: apifox-sync
description: 从代码中提取API接口定义，生成标准OpenAPI 3.0文档，并上传同步到Apifox平台。当用户提到"同步接口"、"上传到apifox"、"导入API文档"、"更新接口文档"时使用。支持从Go/Python/Node.js的handler文件中提取接口。
---

# Apifox Sync - API接口自动同步工具

自动从代码中提取API接口定义，生成OpenAPI文档，并同步到Apifox平台。

## 核心能力

1. **代码分析** - 从 handler/route 文件中提取接口定义
2. **文档生成** - 生成符合 OpenAPI 3.0 标准的 JSON 文档
3. **自动同步** - 使用 `scripts/sync-to-apifox.sh` 上传到 Apifox

## 快速开始

用户说：
- "帮我把最近的接口改动同步到Apifox"
- "上传新增的API到接口文档"
- "这次commit新增了topic接口，同步到Apifox"

## 工作流程

### 步骤1：分析变更的接口

**识别接口信息**：
- HTTP方法 (GET, POST, PUT, DELETE等)
- 路由路径 (如 `/api/v1/topic/list`)
- 请求参数（路径参数、查询参数、Header）
- 请求体结构
- 响应结构（包括成功和错误响应）
- 认证要求

**读取相关的model文件**：
- 数据结构定义
- 字段类型和验证规则
- JSON标签（**注意**：`json:"-"`表示不暴露）
- 字段描述和示例

### 步骤2：生成OpenAPI文档

**重要**：使用 OpenAPI 3.0.0 格式（Apifox 兼容性最好）

基于 `templates/openapi-template.json` 创建文档，确保包含：

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "模块名 API",
    "description": "从commit XXX提取的接口",
    "version": "1.0.0"
  },
  "paths": { ... },
  "components": {
    "schemas": { ... },
    "securitySchemes": { ... }
  }
}
```

**关键规则**：
- ✅ 包含所有HTTP状态码的响应（200, 400, 401, 404, 500等）
- ✅ 提供真实的example数据（不要用 "string", "123" 这种占位符）
- ✅ 标注 required 字段
- ✅ 排除 `json:"-"` 字段（如 prompt 等敏感字段）
- ✅ ObjectID 类型添加 pattern: `^[a-f0-9]{24}$`
- ✅ 时间字段使用 `format: "date-time"`

### 步骤3：上传到Apifox

**使用同步脚本**：

```bash
# 方式1: 直接调用脚本
cd ~/.claude/skills/apifox-sync/scripts
./sync-to-apifox.sh --file "/path/to/generated-openapi.json"

# 方式2: 使用环境变量
export APIFOX_TOKEN="your_token"
export APIFOX_PROJECT_ID="your_project_id"
./sync-to-apifox.sh --file "./openapi.json"
```

脚本会自动：
- 检查环境变量 `APIFOX_TOKEN` 和 `APIFOX_PROJECT_ID`
- 上传到 Apifox API
- 验证响应并报告结果

**响应处理**：
- `200/201` → 成功，显示同步的接口列表
- `401` → Token 无效，提示重新配置
- `404` → 项目不存在，检查 Project ID
- 其他 → 显示详细错误信息

**向用户报告**：
```
✅ 成功同步到Apifox！

同步的接口：
• GET    /api/v1/topic/list          - 获取话题列表
• GET    /api/v1/topic/{topic_id}    - 获取话题详情
• DELETE /api/v1/topic/{topic_id}    - 删除话题

🔗 查看文档: https://app.apifox.com/project/${PROJECT_ID}
```

---

## 代码库适配规则

### Go项目（Gin框架）

**识别handler文件**：`internal/handler/http/*_handler.go`

**提取路由**：
```go
router.GET("/list", handler.listTopics)           // GET /list
router.DELETE("/:topic_id", handler.deleteTopic)  // DELETE /:topic_id
router.POST("/create", handler.createTopic)       // POST /create
```

**提取Model**：`internal/model/*.go`
```go
type Topic struct {
    ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
    Title     string             `bson:"title" json:"title"`
    Prompt    string             `bson:"prompt" json:"-"`  // ⚠️ 不暴露
}
```

**识别认证**：查找`middleware.Auth()`或`ctxvalue.GetUserID(ctx)`

### Python项目（FastAPI/Flask）

**识别route文件**：`app/routes/*.py` 或 `api/endpoints/*.py`

**提取路由**：
```python
@router.get("/list")              # GET /list
@router.delete("/{topic_id}")     # DELETE /{topic_id}
@router.post("/create")           # POST /create
```

**提取Model**：使用Pydantic models

### Node.js项目（Express）

**识别route文件**：`src/routes/*.js` 或 `routes/*.ts`

**提取路由**：
```javascript
router.get('/list', handler.list)
router.delete('/:topic_id', handler.delete)
```

## 批量同步多个模块

当需要同步多个模块的接口时：

1. **识别所有变更的模块** (直接使用 Git 命令)
2. **为每个模块生成独立的OpenAPI文档**
3. **依次上传到Apifox**（或合并成一个文档）
4. **汇总报告**

## 最佳实践

### 1. 提取接口信息时
- ✅ 读取handler函数的完整实现，理解业务逻辑
- ✅ 查看error handling，提取所有可能的错误码
- ✅ 检查参数验证逻辑，了解required/optional
- ✅ 查找相关测试文件，获取真实的示例数据

### 2. 生成OpenAPI文档时
- ✅ 使用有意义的`operationId`（如`listTopics`, `deleteTopic`）
- ✅ 为每个接口添加`tags`用于分组
- ✅ 所有描述使用中文（如果项目是中文团队）
- ✅ 提供真实的example，不要用`string`, `123`这种占位符

### 3. 处理安全字段
- ⚠️ 排除`json:"-"`标签的字段
- ⚠️ 排除密码、token等敏感字段
- ⚠️ 注释中标记为"内部使用"的字段也要排除

### 4. 错误处理
- 如果提取失败，提供清晰的错误信息和建议
- 如果上传失败，保存生成的OpenAPI文件供手动导入
- 如果遇到不认识的代码结构，询问用户

## 凭证配置

使用 `scripts/setup.sh` 交互式配置：
```bash
cd ~/.claude/skills/apifox-sync/scripts
./setup.sh
```

或手动设置环境变量：
```bash
export APIFOX_TOKEN="apifox_xxx"
export APIFOX_PROJECT_ID="1234567"
```

**获取凭证**：
- Token: Apifox → 个人设置 → API 访问令牌
- Project ID: 项目 URL 中的数字，如 `https://app.apifox.com/project/1234567`

## 常见错误

| 错误码 | 原因 | 解决方案 |
|------|------|----------|
| 401 | Token无效或过期 | 重新生成 Access Token |
| 403 | 权限不足 | 确保 Token 有项目编辑权限 |
| 404 | 项目不存在 | 检查 Project ID |
| 400 | OpenAPI格式错误 | 验证生成的 JSON 格式 |

---

**检查清单**：
- [ ] 所有接口都已提取完整（包括路径、方法、参数、响应）
- [ ] Schema 中排除了 `json:"-"` 敏感字段
- [ ] 提供了真实的 example 数据（不是占位符）
- [ ] 所有错误响应都已包含（400, 401, 404, 500等）
- [ ] Token 和 Project ID 配置正确
- [ ] 上传成功并在 Apifox 中可见
