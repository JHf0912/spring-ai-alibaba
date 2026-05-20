# REST API 接口清单

> 自动生成自项目 Controller 源码，共 212 个接口，按模块分组。

---

## 1. Admin Console（`/console/v1/*`）

管理平台后台接口，20 个 Controller，119 个接口。

### 1.1 AuthController — 认证

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/console/v1/auth/login` | 用户登录 | `LoginRequest` | `Result<TokenResponse>` |
| POST | `/console/v1/auth/refresh-token` | 刷新 Token | `RefreshTokenRequest` | `Result<TokenResponse>` |
| POST | `/console/v1/auth/logout` | 退出登录 | Authorization header | `Result<Void>` |

### 1.2 AccountController — 用户管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/accounts/profile` | 获取当前用户信息 | — | `Result<Account>` |
| GET | `/console/v1/accounts` | 用户列表（分页） | `BaseQuery` | `Result<PagingList<Account>>` |
| GET | `/console/v1/accounts/{accountId}` | 获取用户详情 | `accountId` | `Result<Account>` |
| POST | `/console/v1/accounts` | 创建用户 | `Account` | `Result<String>` |
| PUT | `/console/v1/accounts/{accountId}` | 更新用户 | `Account` | `Result<String>` |
| DELETE | `/console/v1/accounts/{accountId}` | 删除用户 | `accountId` | `Result<Void>` |
| PUT | `/console/v1/accounts/change-password` | 修改密码 | `ChangePasswordRequest` | `Result<String>` |

### 1.3 WorkspaceController — 工作空间

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/workspaces` | 工作空间列表 | `BaseQuery` | `Result<PagingList<Workspace>>` |
| GET | `/console/v1/workspaces/{id}` | 工作空间详情 | `workspaceId` | `Result<Workspace>` |
| POST | `/console/v1/workspaces` | 创建工作空间 | `Workspace` | `Result<String>` |
| PUT | `/console/v1/workspaces/{id}` | 更新工作空间 | `Workspace` | `Result<String>` |
| DELETE | `/console/v1/workspaces/{id}` | 删除工作空间 | `workspaceId` | `Result<Void>` |

### 1.4 AppController — 应用管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/apps` | 应用列表（分页） | `AppQuery` | `Result<PagingList<Application>>` |
| GET | `/console/v1/apps/{appId}` | 应用详情 | `appId` | `Result<Application>` |
| POST | `/console/v1/apps` | 创建应用 | `Application` | `Result<String>` |
| PUT | `/console/v1/apps/{appId}` | 更新应用 | `Application` | `Result<String>` |
| DELETE | `/console/v1/apps/{appId}` | 删除应用 | `appId` | `Result<Void>` |
| POST | `/console/v1/apps/{appId}/publish` | 发布应用 | `appId` | `Result<Void>` |
| POST | `/console/v1/apps/{appId}/copy` | 复制应用 | `appId` | `Result<String>` |
| GET | `/console/v1/apps/{appId}/versions` | 应用版本列表 | `AppQuery` | `Result<PagingList<ApplicationVersion>>` |
| GET | `/console/v1/apps/{appId}/versions/{version}` | 版本详情 | `appId`, `version` | `Result<ApplicationVersion>` |

### 1.5 AppChatController — 应用对话

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/console/v1/apps/chat/completions` | 对话补全（同步/SSE） | `AgentRequest` | `String` 或 `SseEmitter` |

### 1.6 WorkflowController — 工作流调试

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/console/v1/apps/workflow/debug/init` | 初始化调试参数 | `InitRequest` | `Result<List<TaskRunParam>>` |
| POST | `/console/v1/apps/workflow/debug/run-task` | 执行调试任务 | `TaskRunRequest` | `Result<TaskRunResponse>` |
| POST | `/console/v1/apps/workflow/debug/get-task-process` | 查询任务状态 | `ProcessGetRequest` | `Result<ProcessGetResponse>` |
| POST | `/console/v1/apps/workflow/debug/resume-task` | 恢复暂停任务 | `TaskResumeRequest` | `Result<TaskResumeResponse>` |
| POST | `/console/v1/apps/workflow/debug/part-graph/run-task` | 执行子图 | `TaskPartGraphRequest` | `Result<TaskPartGraphResponse>` |
| POST | `/console/v1/apps/workflow/debug/part-graph/stop-task` | 停止任务 | `TaskStopRequest` | `Result<Boolean>` |
| POST | `/console/v1/apps/workflow/{appId}/run_stream` | 工作流 SSE 流式执行 | `ApiTaskRunRequest` | `SseEmitter` |

### 1.7 AgentSchemaController — Agent 配置

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/agent-schemas` | 当前工作空间全部 Agent | — | `Result<List<AgentSchemaEntity>>` |
| GET | `/console/v1/agent-schemas/page` | Agent 列表（分页） | `current`, `size` | `Result<PagingList<AgentSchemaEntity>>` |
| GET | `/console/v1/agent-schemas/search` | 按名称搜索 Agent | `name` | `Result<List<AgentSchemaEntity>>` |
| GET | `/console/v1/agent-schemas/{id}` | Agent 详情 | `id` | `Result<AgentSchemaEntity>` |
| POST | `/console/v1/agent-schemas` | 创建 Agent | `AgentSchemaEntity` | `Result<AgentSchemaEntity>` |
| PUT | `/console/v1/agent-schemas/{id}` | 更新 Agent | `AgentSchemaEntity` | `Result<AgentSchemaEntity>` |
| DELETE | `/console/v1/agent-schemas/{id}` | 删除 Agent | `id` | `Result<Void>` |
| PATCH | `/console/v1/agent-schemas/{id}/enabled` | 启用/禁用 Agent | `id`, `enabled` | `Result<Void>` |

### 1.8 ProviderController — 模型提供商

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/providers` | 提供商列表 | `QueryProviderRequest` | `Result<List<ProviderConfigInfo>>` |
| GET | `/console/v1/providers/{provider}` | 提供商详情 | `provider` | `Result<ProviderConfigInfo>` |
| GET | `/console/v1/providers/protocols` | 支持的协议列表 | — | `Result<List<String>>` |
| POST | `/console/v1/providers` | 添加提供商 | `AddProviderRequest` | `Result<Boolean>` |
| PUT | `/console/v1/providers/{provider}` | 更新提供商 | `UpdateProviderRequest` | `Result<Boolean>` |
| DELETE | `/console/v1/providers/{provider}` | 删除提供商 | `provider` | `Result<Boolean>` |
| GET | `/console/v1/providers/{provider}/models` | 提供商下的模型列表 | `provider` | `Result<List<ModelConfigInfo>>` |
| GET | `/console/v1/providers/{provider}/models/{modelId}` | 模型详情 | `provider`, `modelId` | `Result<ModelConfigInfo>` |
| GET | `/console/v1/providers/{provider}/models/{modelId}/parameter_rules` | 模型参数规则 | `provider`, `modelId` | `Result<List<ParameterRule>>` |
| POST | `/console/v1/providers/{provider}/models` | 添加模型 | `AddModelRequest` | `Result<Boolean>` |
| PUT | `/console/v1/providers/{provider}/models/{modelId}` | 更新模型 | `UpdateModelRequest` | `Result<Boolean>` |
| DELETE | `/console/v1/providers/{provider}/models/{modelId}` | 删除模型 | `provider`, `modelId` | `Result<Boolean>` |

### 1.9 ModelController — 模型查询

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/models/{modelType}/selector` | 按类型获取模型分组 | `modelType` | `Result<List<ModelProviderGroup>>` |
| GET | `/console/v1/models/enabled` | 获取已启用模型 | — | `Result<List<Map>>` |

### 1.10 PluginController — 插件管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/plugins` | 插件列表（分页） | `BaseQuery` | `Result<PagingList<Plugin>>` |
| GET | `/console/v1/plugins/{pluginId}` | 插件详情 | `pluginId` | `Result<Plugin>` |
| POST | `/console/v1/plugins` | 创建插件 | `Plugin` | `Result<String>` |
| PUT | `/console/v1/plugins/{pluginId}` | 更新插件 | `Plugin` | `Result<Void>` |
| DELETE | `/console/v1/plugins/{pluginId}` | 删除插件 | `pluginId` | `Result<Void>` |
| GET | `/console/v1/plugins/{pluginId}/tools` | 插件下的工具列表 | `ToolQuery` | `Result<PagingList<Tool>>` |
| GET | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 工具详情 | `pluginId`, `toolId` | `Result<Tool>` |
| POST | `/console/v1/plugins/{pluginId}/tools` | 创建工具 | `Tool` | `Result<String>` |
| PUT | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 更新工具 | `Tool` | `Result<String>` |
| DELETE | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 删除工具 | `pluginId`, `toolId` | `Result<Void>` |
| POST | `/console/v1/plugins/{pluginId}/tools/{toolId}/test` | 测试工具执行 | `ToolExecutionRequest` | `Result<ToolExecutionResult>` |
| POST | `/console/v1/plugins/{pluginId}/tools/{toolId}/publish` | 发布工具 | — | `Result<Void>` |
| POST | `/console/v1/tools/{toolId}/enable` | 启用工具 | `toolId` | `Result<Void>` |
| POST | `/console/v1/tools/{toolId}/disable` | 禁用工具 | `toolId` | `Result<Void>` |
| POST | `/console/v1/tools/query-by-ids` | 按 ID 批量查询工具 | `ToolQuery` | `Result<List<Tool>>` |

### 1.11 ToolController — 工具管理（独立）

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/tools` | 当前空间全部工具 | — | `Result<List<ToolEntity>>` |
| GET | `/console/v1/tools/page` | 工具列表（分页） | `current`, `size` | `Result<PagingList<ToolEntity>>` |
| GET | `/console/v1/tools/search` | 按名称搜索工具 | `name` | `Result<List<ToolEntity>>` |
| GET | `/console/v1/tools/{id}` | 工具详情 | `id` | `Result<ToolEntity>` |
| GET | `/console/v1/tools/plugin/{pluginId}` | 按插件查工具 | `pluginId` | `Result<List<ToolEntity>>` |
| POST | `/console/v1/tools` | 创建工具 | `ToolEntity` | `Result<ToolEntity>` |
| PUT | `/console/v1/tools/{id}` | 更新工具 | `ToolEntity` | `Result<ToolEntity>` |
| DELETE | `/console/v1/tools/{id}` | 删除工具 | `id` | `Result<Void>` |
| PATCH | `/console/v1/tools/{id}/enabled` | 启用/禁用工具 | `id`, `enabled` | `Result<Void>` |

### 1.12 KnowledgeBaseController — 知识库

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/knowledge-bases` | 知识库列表（分页） | `BaseQuery` | `Result<PagingList<KnowledgeBase>>` |
| GET | `/console/v1/knowledge-bases/{kbId}` | 知识库详情 | `kbId` | `Result<KnowledgeBase>` |
| POST | `/console/v1/knowledge-bases` | 创建知识库 | `KnowledgeBase` | `Result<String>` |
| PUT | `/console/v1/knowledge-bases/{kbId}` | 更新知识库 | `KnowledgeBase` | `Result<String>` |
| DELETE | `/console/v1/knowledge-bases/{kbId}` | 删除知识库 | `kbId` | `Result<Void>` |
| POST | `/console/v1/knowledge-bases/query-by-codes` | 按 ID 批量查询 | `KnowledgeBaseQuery` | `Result<List<KnowledgeBase>>` |
| POST | `/console/v1/knowledge-bases/retrieve` | RAG 检索 | `DocumentRetrieverQuery` | `Result<List<DocumentChunk>>` |

### 1.13 DocumentController — 文档管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/knowledge-bases/{kbId}/documents` | 文档列表（分页） | `DocumentQuery` | `Result<PagingList<Document>>` |
| GET | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 文档详情 | `kbId`, `docId` | `Result<Document>` |
| POST | `/console/v1/knowledge-bases/{kbId}/documents` | 创建文档 | `CreateDocumentRequest` | `Result<List<String>>` |
| PUT | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 更新文档 | `Document` | `Result<Void>` |
| DELETE | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 删除文档 | `kbId`, `docId` | `Result<Void>` |
| DELETE | `/console/v1/knowledge-bases/{kbId}/documents/batch-delete` | 批量删除文档 | `DeleteDocumentRequest` | `Result<Void>` |
| PUT | `/console/v1/knowledge-bases/{kbId}/documents/{docId}/re-index` | 重新索引文档 | `IndexDocumentRequest` | `Result<Void>` |

### 1.14 DocumentChunkController — 文档分块

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/documents/{docId}/chunks` | 分块列表（分页） | `BaseQuery` | `Result<PagingList<DocumentChunk>>` |
| POST | `/console/v1/documents/{docId}/chunks` | 创建分块 | `DocumentChunk` | `Result<String>` |
| PUT | `/console/v1/documents/{docId}/chunks/{chunkId}` | 更新分块 | `DocumentChunk` | `Result<Void>` |
| DELETE | `/console/v1/documents/{docId}/chunks/{chunkId}` | 删除分块 | `docId`, `chunkId` | `Result<Void>` |
| DELETE | `/console/v1/documents/{docId}/chunks/batch-delete` | 批量删除分块 | `DeleteChunkRequest` | `Result<Void>` |
| POST | `/console/v1/documents/{docId}/chunks/preview` | 预览分块 | `IndexDocumentRequest` | `Result<List<DocumentChunk>>` |
| PUT | `/console/v1/documents/{docId}/chunks/update-status` | 更新分块启用状态 | `UpdateChunkRequest` | `Result<Void>` |

### 1.15 McpServerController — MCP 服务器

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/mcp-servers` | MCP 服务器列表（分页） | `McpQuery` | `Result<PagingList<McpServerDetail>>` |
| GET | `/console/v1/mcp-servers/{serverCode}` | 服务器详情 | `serverCode`, `need_tools` | `Result<McpServerDetail>` |
| POST | `/console/v1/mcp-servers` | 创建服务器 | `McpServerDetail` | `Result<String>` |
| PUT | `/console/v1/mcp-servers` | 更新服务器 | `McpServerDetail` | `Result<String>` |
| DELETE | `/console/v1/mcp-servers/{serverCode}` | 删除服务器 | `serverCode` | `Result<Void>` |
| POST | `/console/v1/mcp-servers/query-by-codes` | 按 Code 批量查询 | `McpQuery` | `Result<List<McpServerDetail>>` |
| POST | `/console/v1/mcp-servers/debug-tools` | 调试 MCP 工具 | `McpServerCallToolRequest` | `Result<McpServerCallToolResponse>` |

### 1.16 AppComponentController — 应用组件

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/component-servers` | 组件列表（分页） | `AppComponentQuery` | `Result<PagingList<AppComponent>>` |
| GET | `/console/v1/component-servers/app-publishable` | 可发布为组件的应用 | `AppComponentQuery` | `Result<PagingList<Application>>` |
| GET | `/console/v1/component-servers/{code}/detail-by-code` | 按 Code 查组件 | `code` | `Result<AppComponent>` |
| GET | `/console/v1/component-servers/{appId}/detail-by-appid` | 按 AppId 查组件 | `appId` | `Result<AppComponent>` |
| GET | `/console/v1/component-servers/{code}/query-refer` | 查询引用关系 | `code` | `Result<List<AppComponent>>` |
| GET | `/console/v1/component-servers/{appId}/query-config` | 查询组件配置 | `appId` | `Result<AppComponent>` |
| GET | `/console/v1/component-servers/{code}/query-schema` | 查询组件 Schema | `code` | `Result<Map>` |
| POST | `/console/v1/component-servers` | 发布组件 | `AppComponentQuery` | `Result<String>` |
| POST | `/console/v1/component-servers/query-by-codes` | 按 Code 批量查询 | `AppComponentQuery` | `Result<List<AppComponent>>` |
| POST | `/console/v1/component-servers/schema-by-codes` | 批量查询 Schema | `AppComponentQuery` | `Result<Map>` |
| PUT | `/console/v1/component-servers/{code}` | 更新组件 | `AppComponentQuery` | `Result<String>` |
| DELETE | `/console/v1/component-servers/{code}` | 删除组件 | `code` | `Result<Boolean>` |

### 1.17 ApiKeyController — API 密钥

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/api-keys` | API Key 列表（分页） | `BaseQuery` | `Result<PagingList<ApiKey>>` |
| GET | `/console/v1/api-keys/{id}` | API Key 详情 | `id` | `Result<ApiKey>` |
| POST | `/console/v1/api-keys` | 创建 API Key | `ApiKey` | `Result<String>` |
| PUT | `/console/v1/api-keys/{id}` | 更新 API Key | `ApiKey` | `Result<String>` |
| DELETE | `/console/v1/api-keys/{id}` | 删除 API Key | `id` | `Result<Void>` |

### 1.18 FileController — 文件管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/console/v1/files/upload` | 上传文件 | `MultipartFile[]`, `category` | `Result<List<UploadPolicy>>` |
| GET | `/console/v1/files/download` | 下载文件 | `path`, `preview` | 流式输出 |
| POST | `/console/v1/files/upload-policies` | 获取 OSS 上传凭证 | `WebUploadRequest` | `Result<List<WebUploadPolicy>>` |
| GET | `/console/v1/files/get-preview-url` | 获取预览链接 | `path` | `Result<String>` |

### 1.19 Oauth2Controller — OAuth2 登录

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/oauth2/login/github` | 获取 GitHub 授权 URL | — | `Result<String>` |
| GET | `/oauth2/callback/github` | GitHub 回调处理 | `code` | 重定向到前端 |

### 1.20 SystemController — 系统

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/console/v1/system/global-config` | 全局配置（登录方式、上传方式） | — | `Result<GlobalConfig>` |
| GET | `/console/v1/system/health` | 健康检查 | — | `"ok"` |

---

## 2. Admin Core（`/api/*`）

核心业务接口，6 个 Controller，55 个接口。

### 2.1 PromptController — Prompt 管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/api/prompts` | Prompt 列表（分页） | `PromptListRequest` | `Result<PageResult<Prompt>>` |
| GET | `/api/prompt` | Prompt 详情 | `promptKey` | `Result<Prompt>` |
| POST | `/api/prompt` | 创建 Prompt | `PromptCreateRequest` | `Result<Prompt>` |
| PUT | `/api/prompt` | 更新 Prompt | `PromptUpdateRequest` | `Result<Prompt>` |
| DELETE | `/api/prompt` | 删除 Prompt | `promptKey` | `Result<Boolean>` |
| GET | `/api/prompt/versions` | 版本列表（分页） | `PromptVersionListRequest` | `Result<PageResult<PromptVersion>>` |
| GET | `/api/prompt/version` | 版本详情 | `promptKey`, `version` | `Result<PromptVersionDetail>` |
| POST | `/api/prompt/version` | 创建版本 | `PromptVersionCreateRequest` | `Result<PromptVersion>` |
| GET | `/api/prompt/templates` | 模板列表（分页） | `PromptTemplateListRequest` | `Result<PageResult<PromptTemplate>>` |
| GET | `/api/prompt/template` | 模板详情 | `promptTemplateKey` | `Result<PromptTemplateDetail>` |
| POST | `/api/prompt/run` | 运行/调试 Prompt（SSE） | `PromptRunRequest` | `Flux<PromptRunResponse>` |
| GET | `/api/prompt/session` | 获取会话 | `sessionId` | `Result<ChatSession>` |
| DELETE | `/api/prompt/session` | 删除会话 | `sessionId` | `Result<Void>` |

### 2.2 DatasetController — 数据集

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/api/dataset/datasets` | 数据集列表（分页） | `DatasetListRequest` | `Result<PageResult<Dataset>>` |
| GET | `/api/dataset/dataset` | 数据集详情 | `datasetId` | `Result<Dataset>` |
| POST | `/api/dataset/dataset` | 创建数据集 | `DatasetCreateRequest` | `Result<Dataset>` |
| PUT | `/api/dataset/dataset` | 更新数据集 | `DatasetUpdateRequest` | `Result<Dataset>` |
| DELETE | `/api/dataset/dataset` | 删除数据集 | `datasetId` | `Result<Void>` |
| GET | `/api/dataset/datasetVersions` | 版本列表（分页） | `DatasetVersionListRequest` | `Result<PageResult<DatasetVersion>>` |
| POST | `/api/dataset/datasetVersion` | 创建版本 | `DatasetVersionCreateRequest` | `Result<DatasetVersion>` |
| PUT | `/api/dataset/datasetVersion` | 更新版本 | `DatasetVersionUpdateRequest` | `Result<DatasetVersion>` |
| GET | `/api/dataset/dataItems` | 数据项列表（分页） | `DatasetItemListRequest` | `Result<PageResult<DatasetItem>>` |
| GET | `/api/dataset/dataItem` | 数据项详情 | `id` | `Result<DatasetItem>` |
| POST | `/api/dataset/dataItem` | 创建数据项 | `DatasetItemCreateRequest` | `Result<List<DatasetItem>>` |
| PUT | `/api/dataset/dataItem` | 更新数据项 | `DatasetItemUpdateRequest` | `Result<DatasetItem>` |
| DELETE | `/api/dataset/dataItem` | 删除数据项 | `id` | `Result<Void>` |
| GET | `/api/dataset/experiments` | 关联的实验列表 | `DatasetExperimentsListRequest` | `Result<PageResult<Experiment>>` |
| POST | `/api/dataset/dataItemFromTrace` | 从 Trace 创建数据项 | `DataItemCreateFromTraceRequest` | `Result<List<DatasetItem>>` |

### 2.3 EvaluatorController — 评估器

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/api/evaluator/evaluators` | 评估器列表（分页） | `EvaluatorListRequest` | `Result<PageResult<Evaluator>>` |
| GET | `/api/evaluator/evaluator` | 评估器详情 | `id` | `Result<Evaluator>` |
| POST | `/api/evaluator/evaluator` | 创建评估器 | `EvaluatorCreateRequest` | `Result<Evaluator>` |
| PUT | `/api/evaluator/evaluator` | 更新评估器 | `EvaluatorUpdateRequest` | `Result<Evaluator>` |
| DELETE | `/api/evaluator/evaluator` | 删除评估器 | `id` | `Result<Void>` |
| GET | `/api/evaluator/evaluatorVersions` | 版本列表（分页） | `EvaluatorVersionListRequest` | `Result<PageResult<EvaluatorVersion>>` |
| POST | `/api/evaluator/evaluatorVersion` | 创建版本 | `EvaluatorVersionCreateRequest` | `Result<EvaluatorVersion>` |
| POST | `/api/evaluator/debug` | 调试评估器 | `EvaluatorTestRequest` | `Result<EvaluatorDebugResult>` |
| GET | `/api/evaluator/templates` | 模板列表（分页） | `EvaluatorTemplateListRequest` | `Result<PageResult<EvaluatorTemplate>>` |
| GET | `/api/evaluator/template` | 模板详情 | `templateId` | `Result<EvaluatorTemplate>` |
| GET | `/api/evaluator/experiments` | 关联的实验列表 | `EvaluatorExperimentsListRequest` | `Result<PageResult<Experiment>>` |

### 2.4 ExperimentController — 实验

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/api/experiments` | 实验列表（分页） | `ExperimentListRequest` | `Result<PageResult<Experiment>>` |
| GET | `/api/experiment` | 实验详情 | `experimentId` | `Result<Experiment>` |
| GET | `/api/experiment/results` | 实验汇总结果 | `experimentId` | `Result<List<ExperimentEvaluatorResult>>` |
| GET | `/api/experiment/result` | 实验详细结果（分页） | `ExperimentEvaluatorResultDetailListRequest` | `Result<PageResult<...>>` |
| POST | `/api/experiment` | 创建实验 | `ExperimentCreateRequest` | `Result<Experiment>` |
| PUT | `/api/experiment/stop` | 停止实验 | `experimentId` | `Result<Experiment>` |
| PUT | `/api/experiment/restart` | 重启实验 | `experimentId` | `Result<Void>` |
| DELETE | `/api/experiment` | 删除实验 | `experimentId` | `Result<Void>` |

### 2.5 ModelConfigController — 模型配置

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/api/model/supported` | 支持的模型提供商 | — | `Result<List<String>>` |
| GET | `/api/models` | 模型配置列表（分页） | `ModelConfigQueryRequest` | `Result<PageResult<ModelConfigResponse>>` |
| GET | `/api/model` | 模型配置详情 | `id` | `Result<ModelConfigResponse>` |
| GET | `/api/models/enabled` | 已启用的模型列表 | — | `Result<List<ModelConfigResponse>>` |

### 2.6 ObservabilityController — 可观测性

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/api/observability/traces` | Trace 列表（分页） | `TracesQueryRequest` | `Result<PageResult<TraceSpanDTO>>` |
| GET | `/api/observability/traces/{traceId}` | Trace 详情 | `traceId` | `Result<TraceDetailDTO>` |
| GET | `/api/observability/services` | 服务列表 | `ServicesQueryRequest` | `Result<ServicesResponseDTO>` |
| GET | `/api/observability/overview` | 概览统计 | `OverviewQueryRequest` | `Result<OverviewStatsDTO>` |

---

## 3. Admin OpenAPI（`/api/v1/apps/*`）

对外暴露的 Agent/Workflow API，1 个 Controller，5 个接口。

### 3.1 ChatController — 对话与工作流 API

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/api/v1/apps/chat/completions` | Agent 对话补全（同步/SSE） | `AgentRequest` | `Object` |
| POST | `/api/v1/apps/workflow/completions` | 工作流补全（同步/SSE） | `WorkflowRequest` | `Object` |
| POST | `/api/v1/apps/workflow/async-completions` | 异步工作流执行 | `WorkflowRequest` | `Result<TaskRunResponse>` |
| POST | `/api/v1/apps/workflow/stop-completions` | 停止异步任务 | `TaskStopRequest` | `Result<Boolean>` |
| POST | `/api/v1/apps/workflow/async-results` | 查询异步结果 | `AsyncResultRequest` | `Result<AsyncResultResponse>` |

---

## 4. Graph Studio（`graph-studio/api/*`）

可视化 Agent 开发平台接口，4 个 Controller，11 个接口。

### 4.1 ApplicationController — 应用 CRUD

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `graph-studio/api/app` | 应用列表 | — | `R<List<App>>` |
| GET | `graph-studio/api/app/{id}` | 应用详情 | `id` | `R<App>` |
| POST | `graph-studio/api/app` | 创建应用 | `CreateAppParam` | `R<App>` |
| PUT | `graph-studio/api/app` | 更新应用 | `App` | `R<App>` |
| DELETE | `graph-studio/api/app/{id}` | 删除应用 | `id` | `R<Boolean>` |

### 4.2 DSLController — DSL 导入导出

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `graph-studio/api/dsl/export/{id}` | 导出 DSL（JSON） | `id`, `dialect` | `R<String>` |
| GET | `graph-studio/api/dsl/export-file/{id}` | 导出 DSL（文件下载） | `id`, `dialect` | `ResponseEntity<Resource>` |
| POST | `graph-studio/api/dsl/import` | 导入 DSL（JSON） | `DSLParam` | `R<App>` |
| POST | `graph-studio/api/dsl/import-file` | 导入 DSL（文件上传） | `MultipartFile`, `dialect` | `R<App>` |

### 4.3 RunnerController — 应用运行

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `graph-studio/api/run/app/{id}/stream` | 流式运行（SSE） | `id`, `Map inputs` | `Flux<RunEvent>` |
| POST | `graph-studio/api/run/app/{id}/sync` | 同步运行 | `id`, `Map inputs` | `R<RunEvent>` |

### 4.4 GeneratorController — 项目生成

继承 Spring Initializr，无额外接口。通过 `GET /` 获取元数据，`GET /starter.zip` 生成项目。

---

## 5. Studio 嵌入式 UI（`/`）

Agent 调试工具后端，7 个 Controller，19 个接口。

### 5.1 AgentController — Agent 列表

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/list-apps` | 获取可用 Agent 列表 | — | `List<String>` |

### 5.2 ExecutionController — Agent 执行

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/run_sse` | 执行 Agent（SSE 流式） | `AgentRunRequest` | `Flux<SSE>` |
| POST | `/resume_sse` | 恢复 Agent 执行 | `AgentResumeRequest` | `Flux<SSE>` |

### 5.3 GraphController — Graph 管理

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/list-graphs` | 获取可用 Graph 列表 | — | `List<String>` |
| GET | `/graphs/{graphName}/representation` | 获取 Graph Mermaid 图 | `graphName` | `GraphResponse` |

### 5.4 GraphExecutionController — Graph 执行

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| POST | `/graph_run_sse` | 执行 Graph（SSE 流式） | `GraphRunRequest` | `Flux<SSE>` |

### 5.5 ThreadController — Agent 会话线程

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/apps/{appName}/users/{userId}/threads` | 线程列表 | `appName`, `userId` | `List<Thread>` |
| GET | `/apps/{appName}/users/{userId}/threads/{threadId}` | 线程详情 | 3 个 PathVariable | `Thread` |
| POST | `/apps/{appName}/users/{userId}/threads` | 创建线程（自动生成 ID） | `state` (可选) | `Thread` |
| POST | `/apps/{appName}/users/{userId}/threads/{threadId}` | 创建线程（指定 ID） | `state` (可选) | `Thread` |
| DELETE | `/apps/{appName}/users/{userId}/threads/{threadId}` | 删除线程 | 3 个 PathVariable | `Void` |

### 5.6 GraphThreadController — Graph 会话线程

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/graphs/{graphName}/users/{userId}/threads` | 线程列表 | `graphName`, `userId` | `List<Thread>` |
| GET | `/graphs/{graphName}/users/{userId}/threads/{threadId}` | 线程详情 | 3 个 PathVariable | `Thread` |
| POST | `/graphs/{graphName}/users/{userId}/threads` | 创建线程（自动生成 ID） | `state` (可选) | `Thread` |
| POST | `/graphs/{graphName}/users/{userId}/threads/{threadId}` | 创建线程（指定 ID） | `state` (可选) | `Thread` |
| DELETE | `/graphs/{graphName}/users/{userId}/threads/{threadId}` | 删除线程 | 3 个 PathVariable | `Void` |

### 5.7 ChatUiRedirectController — 页面重定向

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/chatui` | 重定向到 ChatUI | — | 302 重定向 |
| GET | `/chatui/` | 重定向到 ChatUI | — | 302 重定向 |

---

## 6. 测试示例（`/test/api/example`）

| 方法 | 路径 | 说明 | 入参 | 返回 |
|------|------|------|------|------|
| GET | `/test/api/example/getOrder` | 测试 GET 接口 | headers | `Map` |
| POST | `/test/api/example/getOrder` | 测试 POST 接口 | `Map body` (orderId) | `Map` |
| POST | `/test/api/example/getOrder/{orderId}` | 测试路径参数 | `orderId`, `Map body` | `Map` |

---

## 统计

| 模块 | 前缀 | Controller 数 | 接口数 |
|------|------|:---:|:---:|
| Admin Console | `/console/v1` | 20 | 119 |
| Admin Core | `/api` | 6 | 55 |
| Admin OpenAPI | `/api/v1/apps` | 1 | 5 |
| Graph Studio | `graph-studio/api` | 4 | 11 |
| Studio UI | `/` | 7 | 19 |
| Test | `/test/api/example` | 1 | 3 |
| **合计** | | **39** | **212** |
