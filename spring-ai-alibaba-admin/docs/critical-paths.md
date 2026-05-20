# 核心测试链路

> 改造时最容易出问题的 8 条链路。基于 API 接口、数据模型、模块依赖分析得出。
> 选择标准：跨模块调用多、状态机复杂、数据一致性要求高、异步流程长。

---

## 链路总览

| # | 链路名 | 起点接口 | 关键节点 | 成功标志 |
|---|--------|----------|----------|----------|
| 1 | 登录鉴权 | `POST /console/v1/auth/login` | Account → Token → Workspace 解析 | 返回 `access_token`，后续请求携带 Token 能访问 `/api/*` |
| 2 | Prompt 版本化 | `POST /api/prompt` | prompt 表 → prompt_version 表 → latest_version 指针更新 | 创建后 `GET /api/prompt?promptKey=X` 返回 `latest_version` = 新版本号 |
| 3 | 数据集全生命周期 | `POST /api/dataset/dataset` | dataset → dataset_version → dataset_item，CASCADE 删除 | 删除 dataset 后，关联的 version 和 item 全部级联清除 |
| 4 | 实验执行 | `POST /api/experiment` | Dataset + Evaluator + Model 三方关联 → 状态机流转 → 结果写入 | experiment.status = `COMPLETED`，experiment_result 有评分记录 |
| 5 | 应用发布 → 对话 | `POST /console/v1/apps/{id}/publish` | application → application_version → status=2 → OpenAPI chat | `POST /api/v1/apps/chat/completions` 返回模型响应 |
| 6 | 知识库文档索引 | `POST /console/v1/knowledge-bases/{kbId}/documents` | document 创建 → RocketMQ 消息 → 索引处理 → index_status 更新 | document.index_status = 3（完成），ES 可检索到向量 |
| 7 | Agent Schema 生成 | `POST /console/v1/agent-schemas` | JSON 配置 → YAML Schema 生成 → 子 Agent 嵌套校验 | `GET /console/v1/agent-schemas/{id}` 返回 yaml_schema 非空 |
| 8 | Trace 查询 | `GET /api/observability/traces` | ES 索引查询 → 时间范围过滤 → 聚合统计 | 返回 code=200，PageResult 结构正确（即使数据为空） |

---

## 详细说明

### 1. 登录鉴权

**为什么容易出问题**: 所有 `/api/*` 和 `/console/v1/*` 接口都依赖 Token。改 Auth 模块会影响全局。

```
POST /console/v1/auth/login
  → AuthController.login()
    → AccountMapper.selectByUsername()
    → Argon2 密码校验
    → JWT Token 生成 (access_token + refresh_token)
    → 返回 TokenResponse
```

**关键节点**:
- `account` 表查询（username 唯一索引）
- Argon2 哈希比对（密码算法变更会破坏兼容性）
- JWT 签名和过期时间
- Workspace 解析（Token 中的 subject → account_id → workspace_id）

**验证方法**:
```bash
# 登录
TOKEN=$(curl -s -X POST http://localhost:8080/console/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"saa","password":"123456"}' | jq -r '.data.access_token')

# 用 Token 访问
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/console/v1/accounts/profile
```

---

### 2. Prompt 版本化

**为什么容易出问题**: 「主表 + 版本表」是 Dataset、Evaluator 的通用模式。改 Prompt 的版本逻辑会影响其他两个模块。

```
POST /api/prompt
  → PromptService.create()
    → INSERT prompt (prompt_key, latest_version=null)
    → INSERT prompt_version (version="0.0.1", status="pre")
    → UPDATE prompt SET latest_version="0.0.1"

POST /api/prompt/version
  → PromptVersionService.createVersion()
    → 校验 version 唯一性 (prompt_key + version)
    → INSERT prompt_version
    → UPDATE prompt.latest_version
```

**关键节点**:
- `prompt` 表 + `prompt_version` 表的一致性（latest_version 指针）
- 版本号唯一约束 (prompt_key + version)
- JSON 字段：`variables`、`model_config` 的序列化/反序列化
- 模板变量替换（`{{variable}}` 格式）

**验证方法**:
```bash
# 创建 Prompt
curl -X POST http://localhost:8080/api/prompt \
  -H "Content-Type: application/json" \
  -d '{"promptKey":"test-prompt","promptDesc":"测试","template":"你好{{name}}","variables":"name"}'

# 检查版本
curl "http://localhost:8080/api/prompt/versions?promptKey=test-prompt"
```

---

### 3. 数据集全生命周期

**为什么容易出问题**: 三层嵌套（dataset → version → item），CASCADE 删除，JSON 列结构配置。

```
POST /api/dataset/dataset
  → DatasetService.create()
    → INSERT dataset (name, columns_config JSON)
    → 返回 Dataset

POST /api/dataset/datasetVersion
  → DatasetVersionService.createVersion()
    → INSERT dataset_version (dataset_id FK)
    → 校验 columns_config 与 dataset 一致

POST /api/dataset/dataItem
  → DatasetItemService.createItem()
    → 校验 data_content 符合 columns_config 定义
    → INSERT dataset_item (dataset_id FK)
    → UPDATE dataset_version.data_count

DELETE /api/dataset/dataset?datasetId=X
  → CASCADE 删除 dataset_version + dataset_item
```

**关键节点**:
- `columns_config` JSON 结构定义列类型（STRING/NUMBER/BOOLEAN/JSON/ARRAY）
- `data_content` JSON 与 `columns_config` 的一致性校验
- `dataset_version.data_count` 计数维护
- FK CASCADE 删除（MySQL 中 `ON DELETE CASCADE` 行为）
- 逻辑删除字段 `deleted`（dataset 和 dataset_item 都有）

**验证方法**:
```bash
# 创建数据集
curl -X POST http://localhost:8080/api/dataset/dataset \
  -H "Content-Type: application/json" \
  -d '{"name":"test","columnsConfig":"[{\"name\":\"input\",\"dataType\":\"STRING\"}]"}'

# 创建版本 + 数据项 → 删除数据集 → 验证级联
```

---

### 4. 实验执行

**为什么容易出问题**: 跨 Dataset、Evaluator、Model 三个模块，状态机有 5 个状态，异步执行涉及模型调用。

```
POST /api/experiment
  → ExperimentService.create()
    → 校验 dataset_id + dataset_version_id 存在
    → 校验 evaluator_config JSON 中的 evaluator_id 都存在
    → INSERT experiment (status=DRAFT)

PUT /api/experiment/restart
  → ExperimentService.restart()
    → 状态校验 (DRAFT/FAILED/STOPPED → RUNNING)
    → 遍历 dataset_item
    → 对每个 item 调用评估对象获取 actual_output
    → 调用 evaluator_version 的 prompt 进行评分
    → INSERT experiment_result (score, reason)
    → 更新 progress 和 status → COMPLETED
```

**关键节点**:
- `experiment` 表关联 `dataset_id` + `dataset_version_id` + `evaluator_config`（JSON 数组）
- 状态机：`DRAFT → RUNNING → COMPLETED/FAILED/STOPPED`，非法转换需拒绝
- `evaluator_config` JSON 解析为 `List<EvaluatorConfig>`
- 模型调用（`ModelConfigParser` 解析 provider + model_name → ChatModel）
- `experiment_result` 按 `evaluator_version_id` 拆分评分
- `progress` 百分比计算

**验证方法**:
```bash
# 创建实验（需先有 dataset 和 evaluator）
curl -X POST http://localhost:8080/api/experiment \
  -H "Content-Type: application/json" \
  -d '{"name":"test","datasetId":1,"datasetVersionId":1,"datasetVersion":"0.0.1","evaluatorConfig":"[{\"evaluatorId\":1,\"evaluatorVersionId\":1}]"}'

# 检查状态流转
curl "http://localhost:8080/api/experiment?experimentId=1"
```

---

### 5. 应用发布 → 对话

**为什么容易出问题**: 从管理后台到 OpenAPI 的跨模块调用，涉及应用配置序列化、版本管理、Agent 执行引擎。

```
POST /console/v1/apps
  → AppService.create()
    → INSERT application (status=1, type=agent/workflow)

POST /console/v1/apps/{id}/publish
  → AppService.publish()
    → 读取最新 application_version.config
    → 更新 application.status = 2 (已发布)
    → 更新 application_version.status = 2

POST /api/v1/apps/chat/completions
  → ChatController.completions()
    → 校验 app_id 存在且 status=2
    → 解析 application_version.config → Agent 配置
    → 调用 Agent Framework 执行
    → 返回模型响应（同步/SSE）
```

**关键节点**:
- `application.status` 状态枚举：1(草稿) → 2(已发布) → 3(发布编辑中)
- `application_version.config` LONGTEXT 中的应用配置序列化
- OpenAPI 接口 `/api/v1/apps/*` 与管理接口 `/console/v1/apps/*` 的鉴权差异
- Agent 配置解析 → ChatModel 调用链
- SSE 流式响应的正确性

**验证方法**:
```bash
# 创建应用
APP_ID=$(curl -s -X POST http://localhost:8080/console/v1/apps \
  -H "Content-Type: application/json" \
  -d '{"name":"test","type":"agent","source":"custom"}' | jq -r '.data')

# 发布
curl -X POST "http://localhost:8080/console/v1/apps/$APP_ID/publish"

# 对话
curl -X POST http://localhost:8080/api/v1/apps/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"appId\":\"$APP_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}"
```

---

### 6. 知识库文档索引

**为什么容易出问题**: 异步流程最长（文件上传 → RocketMQ → 索引处理 → ES 写入），涉及 3 个中间件。

```
POST /console/v1/knowledge-bases/{kbId}/documents
  → DocumentService.create()
    → INSERT document (index_status=1, status=1)
    → 发送 RocketMQ 消息 (topic_saa_studio_document_index)

[异步] RocketMQ Consumer
  → 读取文档内容
  → 分块处理 (process_config)
  → 向量化（调用 Embedding 模型）
  → 写入 ES 索引
  → UPDATE document SET index_status=3

GET /console/v1/knowledge-bases/{kbId}/documents
  → 查询 document 列表（含 index_status）
```

**关键节点**:
- `document.index_status` 状态：1(待处理) → 2(处理中) → 3(完成)
- RocketMQ Topic `topic_saa_studio_document_index` 和 Consumer Group `group_saa_studio_document_index`
- 文件存储路径 `document.path`
- 分块配置 `process_config` JSON
- ES 向量索引写入
- `knowledge_base.total_docs` 计数维护

**验证方法**:
```bash
# 创建知识库
KB_ID=$(curl -s -X POST http://localhost:8080/console/v1/knowledge-bases \
  -H "Content-Type: application/json" \
  -d '{"name":"test","type":"unstructured"}' | jq -r '.data')

# 上传文档
curl -X POST "http://localhost:8080/console/v1/knowledge-bases/$KB_ID/documents" \
  -F "file=@test.txt" -F "type=file"

# 检查索引状态（轮询）
curl "http://localhost:8080/console/v1/knowledge-bases/$KB_ID/documents"
```

---

### 7. Agent Schema 生成

**为什么容易出问题**: 5 种 Agent 类型有不同的配置结构，JSON → YAML 转换，子 Agent 嵌套校验。

```
POST /console/v1/agent-schemas
  → AgentSchemaService.create()
    → 校验 type 合法性 (ReactAgent/ParallelAgent/SequentialAgent/LLMRoutingAgent/LoopAgent)
    → 校验 sub_agents JSON 中引用的 agent_id 都存在
    → INSERT agent_schema (status=DRAFT)
    → 生成 yaml_schema

PATCH /console/v1/agent-schemas/{id}/enabled
  → 校验 Agent 可启用（配置完整性）
  → UPDATE enabled = 0/1
```

**关键节点**:
- `agent_schema.type` 枚举：5 种 Agent 类型
- `handle` LONGTEXT：Agent 处理配置（JSON）
- `sub_agents` LONGTEXT：子 Agent 引用（JSON 数组，可能嵌套）
- `yaml_schema` LONGTEXT：生成的 YAML Schema（从 JSON 转换）
- `input_keys` / `output_key`：接口定义

**验证方法**:
```bash
# 创建 Agent
curl -X POST http://localhost:8080/console/v1/agent-schemas \
  -H "Content-Type: application/json" \
  -d '{"name":"test","type":"ReactAgent","instruction":"你是一个助手"}'

# 检查 YAML 生成
curl "http://localhost:8080/console/v1/agent-schemas/1" | jq '.data.yamlSchema'
```

---

### 8. Trace 查询

**为什么容易出问题**: 跨 ES 索引查询，时间范围参数校验严格，ES 连接配置有两个属性。

```
GET /api/observability/traces
  → ObservabilityController.getTraces()
    → 校验 startTime/endTime 非空 (@NotBlank)
    → TracingQueryBuilder.buildTracesQuery()
      → 时间格式转换
      → 构建 ES BoolQuery
    → ElasticsearchClientWrapper.search()
      → 查询 loongsuite_traces 索引
    → 返回 PageResult<TraceSpanDTO>
```

**关键节点**:
- `TracesQueryRequest.startTime` / `endTime`：`@NotBlank` 校验，时间格式必须正确
- ES 连接配置：`spring.elasticsearch.url`（elasticsearch.yml）和 `spring.elasticsearch.uris`（application.yml）是两个不同属性
- `loongsuite_traces` 索引必须存在
- `parsing_loongsuite_traces` pipeline 的 JSON 解析逻辑
- ES 查询性能（时间范围过大可能超时）

**验证方法**:
```bash
curl "http://localhost:8080/api/observability/traces?pageNumber=1&pageSize=10&startTime=2026-01-01T00:00:00.000Z&endTime=2026-12-31T23:59:59.000Z"
```

---

## 改造风险矩阵

| 链路 | 改 DB Schema | 改 JSON 字段 | 改状态机 | 改中间件依赖 | 改鉴权 |
|------|:---:|:---:|:---:|:---:|:---:|
| 1. 登录鉴权 | 低 | - | - | - | **高** |
| 2. Prompt 版本化 | **高** | **高** | - | - | 低 |
| 3. 数据集全生命周期 | **高** | **高** | - | - | 低 |
| 4. 实验执行 | 中 | **高** | **高** | 中 | 低 |
| 5. 应用发布→对话 | 中 | **高** | **高** | - | **高** |
| 6. 知识库文档索引 | 中 | 中 | **高** | **高** | 低 |
| 7. Agent Schema | 低 | **高** | - | - | 低 |
| 8. Trace 查询 | - | - | - | **高** | 低 |

**最高风险**: 改 JSON 字段结构（影响链路 2/3/4/5/7）和改中间件依赖（影响链路 6/8）。
