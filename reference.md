# Apifox Sync - 高级用法

## Apifox API 文档

### 认证

所有 API 请求需要在 Header 中携带：
```
Authorization: Bearer {YOUR_ACCESS_TOKEN}
X-Apifox-Api-Version: 2024-03-28
```

### 导入 OpenAPI 文档

**正确的 API 端点**：
```bash
curl -X POST "https://api.apifox.com/v1/projects/${PROJECT_ID}/import-openapi?locale=zh-CN" \
  -H "Authorization: Bearer ${APIFOX_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Apifox-Api-Version: 2024-03-28" \
  -d '{
    "input": {
      "url": "https://example.com/openapi.json"
    },
    "options": {
      "endpointOverwriteBehavior": "OVERWRITE_EXISTING",
      "schemaOverwriteBehavior": "OVERWRITE_EXISTING",
      "updateFolderOfChangedEndpoint": false,
      "prependBasePath": false
    }
  }'
```

或直接上传 JSON 数据：
```bash
curl -X POST "https://api.apifox.com/v1/projects/${PROJECT_ID}/import-openapi?locale=zh-CN" \
  -H "Authorization: Bearer ${APIFOX_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Apifox-Api-Version: 2024-03-28" \
  -d '{
    "input": {
      "data": <OpenAPI_JSON_Object>
    },
    "options": {
      "endpointOverwriteBehavior": "MERGE_IF_NOT_EXISTS",
      "schemaOverwriteBehavior": "KEEP_EXISTING"
    }
  }'
```

**覆盖策略选项**：

endpointOverwriteBehavior:
- `OVERWRITE_EXISTING` - 覆盖已存在的接口（默认）
- `MERGE_IF_NOT_EXISTS` - 仅在不存在时添加，保留旧接口
- `ONLY_NEW` - 仅导入新接口

schemaOverwriteBehavior:
- `OVERWRITE_EXISTING` - 覆盖已存在的 Schema（默认）
- `KEEP_EXISTING` - 保留已存在的 Schema
- `OVERWRITE_IF_DIFFERENT` - 仅在不同时覆盖

**重要说明**：
- 当使用本地文件时，`input` 字段需要传递**字符串化的 JSON**
- sync-to-apifox.sh 脚本会自动处理 JSON 转义

## 常见代码模式识别

### Go + Gin 框架

**路由注册模式**：
```go
// Pattern 1: 函数注册
router.GET("/list", handler.listItems)
router.POST("/create", handler.createItem)
router.PUT("/:id", handler.updateItem)
router.DELETE("/:id", handler.deleteItem)

// Pattern 2: 方法注册
router.GET("/list", h.List)

// Pattern 3: 路由组
v1 := router.Group("/api/v1")
{
    v1.GET("/list", handler.listItems)
    v1.POST("/create", handler.createItem)
}

// Pattern 4: 带中间件
authenticated := router.Group("/api/v1")
authenticated.Use(middleware.Auth())
{
    authenticated.GET("/list", handler.listItems)
}
```

**Handler函数模式**：
```go
func (h *handler) listItems(c *gin.Context) {
    // 1. 获取认证信息
    userID, ok := ctxvalue.GetUserID(ctx)

    // 2. 参数验证
    param := c.Query("param")
    if param == "" {
        respondError(c, errs.New(http.StatusBadRequest, "param required"))
        return
    }

    // 3. 业务逻辑
    items, err := h.repo.List(ctx, userID)

    // 4. 错误处理
    if err != nil {
        respondError(c, errs.Wrap(err, http.StatusBadGateway, "failed"))
        return
    }

    // 5. 成功响应
    c.JSON(http.StatusOK, response)
}
```

**Model定义模式**：
```go
type Model struct {
    ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
    Name      string             `bson:"name" json:"name"`
    Secret    string             `bson:"secret" json:"-"`  // 不暴露
    CreatedAt time.Time          `bson:"created_at" json:"created_at"`
}
```

### Python + FastAPI

**路由定义模式**：
```python
# Pattern 1: 装饰器
@router.get("/list")
async def list_items(
    param: str = Query(None, description="参数描述"),
    current_user: User = Depends(get_current_user)
):
    return {"items": items}

# Pattern 2: 路径参数
@router.delete("/{item_id}")
async def delete_item(item_id: str):
    return Response(status_code=204)
```

**Pydantic Model**：
```python
class Item(BaseModel):
    id: str
    name: str
    secret: str = Field(exclude=True)  # 不暴露
    created_at: datetime
```

### Node.js + Express

**路由定义模式**：
```javascript
// Pattern 1: 直接定义
router.get('/list', async (req, res) => {
    res.json({ items: [] });
});

// Pattern 2: Controller
router.get('/list', itemController.list);

// Pattern 3: 中间件
router.get('/list', authMiddleware, itemController.list);
```

## 复杂场景处理

### 场景1: 路径参数提取

Go代码：
```go
router.DELETE("/:topic_id", handler.deleteTopic)
topicID := c.Param("topic_id")
```

生成OpenAPI：
```json
{
  "parameters": [
    {
      "name": "topic_id",
      "in": "path",
      "required": true,
      "schema": {
        "type": "string",
        "pattern": "^[a-f0-9]{24}$"
      }
    }
  ]
}
```

### 场景2: 查询参数提取

Go代码：
```go
limit := c.Query("limit")
createdAt := c.Query("created_at")
```

生成OpenAPI：
```json
{
  "parameters": [
    {
      "name": "limit",
      "in": "query",
      "required": false,
      "schema": {
        "type": "integer"
      }
    }
  ]
}
```

### 场景3: 请求体提取

Go代码：
```go
var req CreateRequest
if err := c.ShouldBindJSON(&req); err != nil {
    // ...
}
```

生成OpenAPI：
```json
{
  "requestBody": {
    "required": true,
    "content": {
      "application/json": {
        "schema": {
          "$ref": "#/components/schemas/CreateRequest"
        }
      }
    }
  }
}
```

### 场景4: 多种响应状态

Go代码：
```go
if err != nil {
    if errors.Is(err, repo.ErrNotFound) {
        respondError(c, errs.New(http.StatusNotFound, "not found"))
        return
    }
    respondError(c, errs.Wrap(err, http.StatusBadGateway, "failed"))
    return
}
c.JSON(http.StatusOK, data)
```

生成OpenAPI：
```json
{
  "responses": {
    "200": { "description": "成功" },
    "404": { "description": "不存在" },
    "502": { "description": "数据库错误" }
  }
}
```

## 从数据库或测试文件获取示例数据

### 从测试文件提取

如果存在 `*_test.go` 文件：
```go
func TestListTopics(t *testing.T) {
    mockData := []Topic{
        {
            ID:    "674403e9dcde9a123456789a",
            Title: "测试标题",
        },
    }
}
```

可以将这些数据用作 OpenAPI 的 example。

### 从数据库查询（谨慎使用）

如果有必要，可以查询数据库获取真实数据：
```bash
# MongoDB
mongosh --eval 'db.topics.findOne()'

# PostgreSQL
psql -c "SELECT * FROM topics LIMIT 1"
```

---

## 限制和解决方案

| 限制 | 影响 | 解决方案 |
|------|------|----------|
| 动态路由难以识别 | 无法自动提取 | 手动补充或使用代码注释标记 |
| 复杂的参数验证 | Schema 可能不准确 | 参考 validator 标签 |
| 内部 API 不想暴露 | 可能误同步 | 在请求时明确指定需要同步的接口 |
| 多版本 API | 路径冲突 | 按版本分组或使用 tag |
